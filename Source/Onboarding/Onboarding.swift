//
//  Onboarding.swift
//  FBTT
//
//  Created by Christoph on 5/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Analytics
import CrashReporting

enum OnboardingError: Error {

    case invalidCountryCode
    case invalidPhoneNumber
    case invalidIdentity(String)
    case invalidVerificationCode
    case staleVerificationCode
    case other(Error?)

    static func optional(_ error: Error?) -> OnboardingError? {
        guard let error = error else { return nil }
        return OnboardingError.other(error)
    }
}

// stateless service class, just does the work
class Onboarding {

    typealias StartCompletion = ((Context?, StartError?) -> Void)
    typealias ResetCompletion = (() -> Void)

    struct Context {

        let identity: Identity
        let network: NetworkKey
        let signingKey: HMACKey?
        let bot: Bot

        var about: About?
    }

    enum StartError: Error {
        case apiError(Error?)
        case botError(Error?)
        case cannotOnboardWhileLoggedIn
        case configurationFailed
        case invalidBirthdate
        case invalidPhoneNumber
        case invalidName
        case resumeNotNecessary
        case secretFailed(Error?)
        case failed(Error)
    }

    /// If the specified user input is valid, begins the identity registration process:
    /// 1. Create secret and identity (public key)
    /// 2. Create an AppConfiguration with the secret
    /// 3. Creates an OnboardingContext from the configuration
    /// 4. Logs into the bot
    /// 5. ~~Joins the Planetary API (creates user directory Person record)~~
    /// 6. Publishes an About
    /// If these steps are successful, `Onboarding.didStart()` is called to set
    /// the `Onboarding.status` for the created identity and the configuration is
    /// saved.  This is what will allow onboarding to resume if the app is backgrounded
    /// or crashes.
    /// If any of these steps fail, `Onboarding.reset()` should be called before
    /// another attempt is made.
    ///
    /// IMPORTANT!
    /// You can force a failure in `VerseAPI.join()` by specifying a particular
    /// name that the API will reject with a 500 error.  This is useful to simulate the
    /// API failing and to test the reset and resume mechanisms.
    /// X5GBl8BzsRaQ
    @MainActor static func createProfile(from data: OnboardingStepData) async throws -> Context {
        
        guard let birthdate = data.birthdate, birthdate.olderThan(yearsAgo: 16) else {
            throw StartError.invalidBirthdate
        }
        
        // Phone verification is not used anymore
        // guard phone.isValidPhoneNumber else { completion(nil, .invalidPhoneNumber); return }
        
        if let name = data.name {
            guard name.isValidName else {
                throw StartError.invalidName
            }
        }
        
        guard Bots.current.identity == nil else {
            throw StartError.cannotOnboardWhileLoggedIn
        }
        
        var secret: Secret
        
        do {
            secret = try await GoBot.shared.createSecret()
        } catch {
            throw StartError.secretFailed(error)
        }
        
        // create app configuration with name and time stamp
        let configuration = AppConfiguration(with: secret)
        configuration.name = "\(data.name ?? secret.identity) (\(Date().shortDateTimeString))"
        configuration.joinedPlanetarySystem = data.joinPlanetarySystem
        
        if data.useTestNetwork {
            configuration.ssbNetwork = Environment.Networks.test
        } else {
            configuration.ssbNetwork = Environment.Networks.mainNet
        }
        
        // Safe to unwrap as configuration has secret, network and bot
        var context = Context(from: configuration)!
        
        // login to bot
        do {
            try await context.bot.login(config: configuration, fromOnboarding: true)
        } catch {
            throw StartError.botError(error)
        }
        
        // publish image
        var profileImageMetadata: ImageMetadata?
        if let image = data.image {
            do {
                profileImageMetadata = try await context.bot.addBlob(jpegOf: image, largestDimension: 1000)
            } catch {
                // We log but don't throw because we don't want
                // to prevent the user from completing onboarding
                Log.error("Error setting profile picture: \(error.localizedDescription)")
            }
        }
        
        // publish about
        if let name = data.name {
            do {
                let about = About(
                    identity: secret.identity,
                    name: name,
                    description: data.bio,
                    image: profileImageMetadata,
                    publicWebHosting: data.publicWebHosting
                )
                _ = try await context.bot.publish(content: about)
                context.about = about
            } catch {
                throw StartError.botError(error)
            }
        }
        
        // track
        if let network = configuration.network {
            CrashReporting.shared.identify(
                identifier: secret.identity,
                name: data.name,
                networkKey: network.string,
                networkName: network.name
            )
            Analytics.shared.identify(
                identifier: secret.identity,
                name: data.name,
                network: network.string
            )
        }
        
        var operations = [Operation]()

        if data.followPlanetary {
            let followPlanetaryOperation = FollowOperation(identity: Environment.PlanetarySystem.planetaryIdentity)
            operations.append(followPlanetaryOperation)
        }
        
        let bundle = Bundle(path: Bundle.main.path(forResource: "Preload", ofType: "bundle")!)!
        let preloadOperation = LoadBundleOperation(bundle: bundle)
        
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        refreshOperation.addDependency(preloadOperation)
        
        operations += [
            preloadOperation,
            refreshOperation,
        ]
        
        for operation in operations {
            AppController.shared.addOperation(operation)
        }
        
        // done
        Onboarding.didStart(configuration: configuration, secret: secret)
        return context
    }

    /// Assuming the very last of `Onboarding.start()` completes successfully, this should
    /// be called to set the `Onboarding.status` for the created identity.
    private static func didStart(configuration: AppConfiguration,
                                 secret: Secret) {
        // TODO should be one command to do all this
        // TODO doing this here makes it hard to revert if something fails
        configuration.apply()
        AppConfigurations.add(configuration)
        AppConfigurations.current.save()

        // mark as started
        Onboarding.set(status: .started, for: secret.identity)
    }

    /// If `Onboarding.start()` fails, then this should be called to prepare for another attempt.
    /// Note that this does not change the `Onboarding.status` for any identity, because that
    /// should not have been set.  Check out `Onboarding.start()` to see all the work that is
    /// done, and to use a template to know what work to undo.
    static func reset(completion: @escaping ResetCompletion) {
        Task {
            do {
                try await Bots.current.logout()
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            Analytics.shared.forget()
            completion()
        }
    }

    /// Gathers all necessary data for an Onboarding.Context to resume the onboarding experience.
    /// This does not check the current identity's Onboarding.Status first, although it can be expected
    /// that this is only called for identities that need to resume onboarding.  In addition to loading the
    /// current AppConfiguration and creating an Onboarding.Context from it, this will also gather the
    /// published `About` and `Person` record from the user directory API.  Both of these steps
    /// MUST BE completed before `resume()` will work.  Check out `start()` and see that
    /// it does not write status until all those steps are complete.
    static func resume(completion: @escaping StartCompletion) {
        
        Task {
            guard let configuration = AppConfiguration.current,
                var context = Context(from: configuration) else {
                completion(nil, .configurationFailed)
                return
            }
            
            do {
                try await Bots.current.login(config: configuration, fromOnboarding: true)
            } catch {
                completion(context, .botError(error))
            }
            Bots.current.setRestoring(false)

            // get About for context identity
            Bots.current.about(identity: context.identity) {
                about, error in
                guard let about = about else {
                    // Known case, pub api call failed in previous onboarding
                    completion(context, .botError(error))
                    return
                }
                context.about = about
                
                CrashReporting.shared.identify(
                    identifier: about.identity,
                    name: about.name,
                    networkKey: context.network.string,
                    networkName: context.network.name
                )
                Analytics.shared.identify(identifier: about.identity,
                                          name: about.name,
                                          network: context.network.name)
                
                completion(context, nil)
            }
        }
    }
}
