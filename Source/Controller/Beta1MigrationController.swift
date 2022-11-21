//
//  Beta1MigrationController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftUI
import SQLite
import Logger
import CrashReporting
import Combine
import simd
import Analytics

/// An enumeration of things that can go wrong with the "beta1" migration.
enum Beta1MigrationError: Error {
    case couldNotGetCompletionMessageCount
    
    var localizedDescription: String {
        switch self {
        case .couldNotGetCompletionMessageCount:
            return "Beta1 migration could not get number of messages from SQLite."
        }
    }
}

/// Manages the "beta1" migration, by dropping the go-ssb and view databases and showing a screen explaining this to
/// the user.
///
/// The go-ssb on-disk database format changed with no migration path circa 2022, so we wrote this custom flow in Swift
/// to drop all data and resync from the network.
@MainActor 
class Beta1MigrationController: ObservableObject, Beta1MigrationViewModel {
    
    // MARK: - Properties
    
    static let beta1MigrationStartKey = "StartedBeta1Migration"
    static let beta1MigrationCompleteKey = "CompletedBeta1Migration"
    static let beta1MigrationProgress = "Beta1MigrationProgress"
    static let beta1MigrationProgressTarget = "Beta1MigrationProgressTarget"
    
    /// A number between 0 and 1.0 representing the progress of the migration.
    @Published var progress: Float = 0
    
    /// A flag that is used to show a confirmation alert before dismissing the migration screen early.
    @Published var shouldConfirmDismissal = false
    
    /// A block that can be called to dismiss the migration view.
    private var dismissHandler: () -> Void
    
    /// The number of messages that were in the database before the migration started.
    private var completionMessageCount: Int
    
    /// An on-disk key value store used to track the status of the migration.
    private var userDefaults: UserDefaults
    
    private var cancellabes = [AnyCancellable]()
    
    private var appConfiguration: AppConfiguration
    
    private var appController: AppController
    
    // MARK: - Public Interface
    
    /// Checks if the migration has already run then drops GoBot database and presents migration UI if it hasn't.
    /// Notes that this function relies on `LaunchViewController` to filter out new and restoring users.
    class func performBeta1MigrationIfNeeded(
        appConfiguration: AppConfiguration,
        appController: AppController,
        userDefaults: UserDefaults
    ) async throws -> Bool {
        guard let bot = appConfiguration.bot as? GoBot else {
            return false
        }
        
        let dbPath = try appConfiguration.databaseDirectory()
        let dbExists = FileManager.default.fileExists(atPath: dbPath)
        let dbVersion = userDefaults.string(forKey: GoBot.versionKey)
        let didStart = userDefaults.bool(forKey: Self.beta1MigrationStartKey)
        let didComplete = userDefaults.bool(forKey: Self.beta1MigrationCompleteKey)
        if !dbExists || didComplete || (!didStart && dbVersion != nil) {
            return false
        }
        
        Log.info("Beta1 migration triggered.")
        Analytics.shared.trackDidStartBeta1Migration()
        
        let controller = Beta1MigrationController(
            appConfiguration: appConfiguration,
            appController: appController,
            userDefaults: userDefaults,
            dismissHandler: {
                Task { await appController.dismiss(animated: true) }
            }
        )
        let view = Beta1MigrationView(viewModel: controller)
        let hostingController = await UIHostingController(rootView: view)
        await MainActor.run {
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .crossDissolve
        }
        await appController.present(hostingController, animated: true)
     
        bot.isRestoring = true
   
        if !userDefaults.bool(forKey: beta1MigrationStartKey) {
            try await bot.dropDatabase(for: appConfiguration)
            Log.info("Data dropped successfully. Restoring data from the network.")
            userDefaults.set(true, forKey: beta1MigrationStartKey)
            userDefaults.set(bot.version, forKey: GoBot.versionKey)
            userDefaults.synchronize()
        } else {
            Log.info("Resuming Beta1 migration")
            controller.progress = userDefaults.float(forKey: beta1MigrationProgress)
        }
        
        try await bot.login(config: appConfiguration)
        await controller.bindProgress(to: bot)
        
        return true
    }
    
    // MARK: - Internal functions
    
    private init(
        appConfiguration: AppConfiguration,
        appController: AppController,
        userDefaults: UserDefaults,
        dismissHandler: @escaping () -> Void
    ) {
        self.appConfiguration = appConfiguration
        self.appController = appController
        self.dismissHandler = dismissHandler
        self.userDefaults = userDefaults
        
        self.completionMessageCount = Self.computeProgressTarget(from: appConfiguration, userDefaults: userDefaults)
        Log.info("Total number of messages to resync: \(completionMessageCount)")
        userDefaults.set(completionMessageCount, forKey: Self.beta1MigrationProgressTarget)
        userDefaults.synchronize()
    }

    /// Computes the `completionMessageCount` which is used in the progress bar.
    private class func computeProgressTarget(
        from appConfiguration: AppConfiguration,
        userDefaults: UserDefaults
    ) -> Int {
        if let completionMessageCount = userDefaults.object(forKey: Self.beta1MigrationProgressTarget) as? Int {
            return completionMessageCount
        } else {
            do {
                return try Self.getNumberOfMessagesInViewDatabase(with: appConfiguration)
            } catch {
                let migrationError = Beta1MigrationError.couldNotGetCompletionMessageCount
                Log.optional(error, migrationError.localizedDescription)
                CrashReporting.shared.reportIfNeeded(
                    error: migrationError,
                    metadata: ["underlyingError": error.localizedDescription]
                )
                return 1
            }
        }
    }
    
    /// Wires up our published `progress` property to the statistics service.
    private func bindProgress(to bot: GoBot) async {
        Timer.publish(every: 1, on: .main, in: .default)
            .autoconnect()
            .asyncFlatMap(maxPublishers: .max(1)) { _ in
                (try? bot.database.messageCount()) ?? 0
            }
            // Ignore the first statistics because the database doesn't get dropped right away
            .dropFirst()
            .map { (currentMessageCount: Int) -> Float in
                // Calculate completion percentage
                let completionFraction = Float(currentMessageCount) / Float(self.completionMessageCount)
                return completionFraction.clamped(to: 0.0...1.0)
            }
            .receive(on: RunLoop.main)
            .sink(receiveValue: { progress in
                self.progress = progress
                self.userDefaults.set(progress, forKey: Self.beta1MigrationProgress)
                self.userDefaults.synchronize()
            })
            .store(in: &self.cancellabes)
        
        // Print progress only every 60 seconds
        Timer.publish(every: 60, on: .main, in: .default)
            .autoconnect()
            .sink(receiveValue: { progress in
                Log.info("Resync progress: \(self.progress)")
            })
            .store(in: &self.cancellabes)

    }
    
    /// This opens up a special connection to the SQLLite database and retrieves the total message count.
    /// We duplicate code from `ViewDatabase` on purpose. This way if the `ViewDatabase` schema changes in future
    /// releases this migration will still work in the unlikely event someone updates a very old installation of
    /// Planetary and opens it up.
    private static func getNumberOfMessagesInViewDatabase(with configuration: AppConfiguration) throws -> Int {
        let dbConnection = try Connection(try dbPath(with: configuration))
        let msgs = Table("messages")
        let colClaimedAt = Expression<Double>("claimed_at")
        let sixMonthsAgo = Date().millisecondsSince1970 - 1000 * 60 * 60 * 24 * 30 * 6
        return try dbConnection.scalar(
            msgs.count.where(colClaimedAt > sixMonthsAgo)
        ) + configuration.numberOfPublishedMessages
    }
    
    private static func dbPath(with configuration: AppConfiguration) throws -> String {
        let directory = try configuration.databaseDirectory()
        return "\(directory)/schema-built\(ViewDatabase.schemaVersion).sqlite"
    }
    
    // MARK: Handle User Interation
    
    /// Called by the Beta1MigrationView when the user wants to dismiss the migration screen. 
    func confirmDismissal() {
        guard progress <= 0.995 else {
            return
        }
        
        shouldConfirmDismissal = true
    }
    
    func dismissPressed() {
        Log.info("User dismissed Beta1MigrationView with progress: \(progress)")
        userDefaults.set(true, forKey: Self.beta1MigrationCompleteKey)
        userDefaults.synchronize()
        var syncedMessages = -1
        do {
            syncedMessages = try Self.getNumberOfMessagesInViewDatabase(with: appConfiguration)
        } catch {
            Log.optional(error)
        }
        Analytics.shared.trackDidDismissBeta1Migration(
            syncedMessages: syncedMessages,
            totalMessages: completionMessageCount
        )
        appConfiguration.bot?.isRestoring = false

        cancellabes.forEach { $0.cancel() }
        dismissHandler()
        appController.showMainViewController(animated: false)
    }
}
