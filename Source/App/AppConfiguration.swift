//
//  AppConfiguration.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import CryptoKit

/// Represents the set of high-level properties governing the app, like the user's identity, network key, etc.
/// These configurations can be switched out at runtime much like logging in/out of an account.
///
/// The AppConfiguration is stored in the keychain, protecting the user's secret key in case of database corruption.
/// A single device can have many AppConfigurations (see the extensions to the `AppConfigurations` typealias) but only
/// one can be in use at a time.
///
/// The AppConfiguration is also used to prevent feed forks in some cases by storing the number of published messages.
class AppConfiguration: NSObject, NSCoding, Identifiable {
    
    var id: String {
        let idComponents: [String] = [
            secret.identity,
            name,
            hmacKey?.string ?? "null",
            network?.string ?? "null",
        ]
        let idString = idComponents.joined(separator: "&@!(#$*")
        return SHA256.hash(data: idString.data(using: .utf8)!).description
    }

    // MARK: Editable properties

    var name: String = "New configuration"
    
    /// The number of messages this user has published. This number is used to prevent the user from publishing before
    /// their feed has fully synced, which "forks" or breaks it forever.
    /// Should be kept up-to-date by the `Bot`.
    var numberOfPublishedMessages: Int = 0
    
    /// A bool indicating whether the user has opted to join the "Planetary System". Joining the Planetary System means
    /// the system pubs will follow you automatically.
    var joinedPlanetarySystem = false

    private var networkDidChange = false
    var network: NetworkKey? {
        didSet {
            self.networkDidChange = true
        }
    }

    private var secretDidChange = false
    var secret: Secret {
        didSet {
            self.secretDidChange = true
        }
    }

    private var botDidChange = false
    var bot: Bot? {
        didSet {
            self.botDidChange = true
        }
    }

    // MARK: Calculated properties

    // Note that this is based on the configured network key.
    // Any non-SSB network must have a non-nil value.
    var hmacKey: HMACKey? {
        get {
            // This is legacy code. We should migrate to storing this in the keychain along with everything else.
            if self.network == Environment.Networks.mainNet.key {
                return nil
            } else if self.network == Environment.Networks.test.key {
                return Environment.Networks.test.hmac
            } else {
                return _hmacKey
            }
        }
        set {
            _hmacKey = newValue
        }
    }
    private var _hmacKey: HMACKey?

    // Alias property for `hmacKey`
    var signingKey: HMACKey? {
        self.hmacKey
    }

    var identity: Identity {
        self.secret.identity
    }

    var canLaunch: Bool {
        self.network != nil &&
            self.bot != nil
    }
    
    var ssbNetwork: SSBNetwork? {
        get {
            guard let key = network else {
                return nil
            }

            return SSBNetwork(
                key: key,
                hmac: hmacKey
            )
        }
        set {
            network = newValue?.key
            hmacKey = newValue?.hmac
        }
    }
    
    var systemPubs: [Star] {
        switch ssbNetwork {
        case Environment.Networks.mainNet:
            return Environment.PlanetarySystem.systemPubs
        case Environment.Networks.test:
            return Environment.TestNetwork.systemPubs
        default:
            return []
        }
    }
    
    var communityPubs: [Star] {
        switch ssbNetwork {
        case Environment.Networks.mainNet:
            return Environment.PlanetarySystem.communityPubs
        case Environment.Networks.test:
            return Environment.TestNetwork.communityPubs
        default:
            return []
        }
    }
    
    func databaseDirectory() throws -> String {
        // lookup Application Support folder for bot and database
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory,
            .userDomainMask,
            true
        )
        
        guard appSupportDirs.count > 0 else {
            throw GoBotError.unexpectedFault("no support dir")
        }
        
        guard let networkKey = network else {
            throw GoBotError.unexpectedFault("No network key in configuration.")
        }

        return appSupportDirs[0]
            .appending("/FBTT")
            .appending("/\(networkKey.hexEncodedString())")
    }

    // MARK: Lifecycle

    init(with secret: Secret) {
        self.secret = secret
        super.init()
        self.setDefaultName()
        self.bot = Bots.bot(named: "GoBot")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let secretString = aDecoder.decodeObject(forKey: "secret") as? String,
            let secret = Secret(from: secretString) else {
            return nil
        }
        self.secret = secret
        
        guard let name = aDecoder.decodeObject(forKey: "name") as? String else { return nil }
        self.name = name
        if let data = aDecoder.decodeObject(forKey: "network") as? Data { self.network = NetworkKey(base64: data) } else { self.network = nil }
        if let named = aDecoder.decodeObject(forKey: "bot") as? String { self.bot = Bots.bot(named: named) } else { self.bot = nil }
        if aDecoder.containsValue(forKey: "numberOfPublishedMessages") {
            self.numberOfPublishedMessages = aDecoder.decodeInteger(forKey: "numberOfPublishedMessages")
        }
        if aDecoder.containsValue(forKey: "joinedPlanetarySystem") {
            self.joinedPlanetarySystem = aDecoder.decodeBool(forKey: "joinedPlanetarySystem")
        }
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.name, forKey: "name")
        aCoder.encode(secret.jsonString(), forKey: "secret")
        if let network = self.network { aCoder.encode(network.data, forKey: "network") }
        if let bot = self.bot { aCoder.encode(bot.name, forKey: "bot") }
        aCoder.encode(numberOfPublishedMessages, forKey: "numberOfPublishedMessages")
        aCoder.encode(joinedPlanetarySystem, forKey: "joinedPlanetarySystem")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let configuration = object as? AppConfiguration else { return false }
        return configuration.name == self.name && configuration.identity == self.identity
    }
    
    // MARK: - Keychain interaction
    
    static var current: AppConfiguration? {
        Keychain.configuration
    }

    func apply() {
        Keychain.configuration = self
        AppConfigurations.add(self)
    }

    func unapply() {
        Keychain.configuration = nil
    }

    func unapplyIfCurrent() {
        if self.isCurrent { self.unapply() }
    }
    
}

extension AppConfiguration {

    static var hasCurrent: Bool {
        AppConfiguration.current != nil
    }

    static var needsToBeCreated: Bool {
        AppConfiguration.current == nil
    }
    
    var isCurrent: Bool {
        self.identity == AppConfiguration.current?.identity
    }

    static func isCurrent(_ identity: Identity) -> Bool {
        guard let configuration = self.current else { return false }
        return configuration.identity == identity
    }
}

extension AppConfiguration {

    func setDefaultName(_ name: String? = nil) {
        let dateString = DateFormatter.localizedString(from: Date(),
                                                       dateStyle: .short,
                                                       timeStyle: .short)
        self.name = "\(name ?? "") \(dateString)"
    }
}

typealias AppConfigurations = [AppConfiguration]

fileprivate extension Keychain {

    // TODO https://app.asana.com/0/914798787098068/1149043570373553/f
    // TODO if the keychain does not unlock fast enough then this will be nil
    static var configuration: AppConfiguration? {
        get {
            guard let data = Keychain.data(for: "app.configuration") else { return nil }
            return AppConfiguration.from(data)
        }
        set {
            if let data = newValue?.toData() {
                Keychain.set(data, for: "app.configuration")
            } else {
                Keychain.delete("app.configuration")
            }
        }
    }
}
