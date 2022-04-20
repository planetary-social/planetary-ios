//
//  Beta1MigrationCoordinator.swift
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
class Beta1MigrationCoordinator: ObservableObject, Beta1MigrationViewModel {
    
    // MARK: - Properties
    
    /// A number between 0 and 1.0 representing the progress of the migration.
    @Published var progress: Float = 0
    
    /// A block that can be called to dismiss the migration view.
    private var dismissHandler: () -> Void
    
    /// The number of messages that were in the database before the migration started.
    private var completionMessageCount: Int
    
    /// An on-disk key value store used to track the status of the migration.
    private var userDefaults: UserDefaults
    
    private var cancellabes = [AnyCancellable]()
    
    // MARK: - Public Interface
    
    class func performBeta1MigrationIfNeeded(
        appConfiguration: AppConfiguration,
        appController: AppController,
        userDefaults: UserDefaults
    ) async throws -> Bool {
        guard let bot = appConfiguration.bot as? GoBot else {
            return false
        }
        
        // todo: include network key
        let version = userDefaults.string(forKey: "GoBotDatabaseVersion")
        guard version == nil else {
            return false
        }
        
        Log.info("Beta1 migration triggered.")
        
        let coordinator = Beta1MigrationCoordinator(
            appConfiguration: appConfiguration,
            userDefaults: userDefaults,
            dismissHandler: {
                Task { await appController.dismiss(animated: true) }
            }
        )
        let view = await Beta1MigrationView(viewModel: coordinator)
        let hostingController = await UIHostingController(rootView: view)
        await appController.present(hostingController, animated: true)
        
        try await bot.dropDatabase(for: appConfiguration)
        Log.info("Data dropped successfully. Restoring data from the network.")
        userDefaults.set(true, forKey: "StartedBeta1Migration")
        userDefaults.set(bot.version, forKey: "GoBotDatabaseVersion")
        userDefaults.synchronize()
        
        try await bot.login(config: appConfiguration)
        let statisticsService = BotStatisticsServiceAdaptor(bot: bot)
        await coordinator.bindProgress(to: statisticsService)
        
        return true
    }
    
    // MARK: - Internal functions
    
    private init(
        appConfiguration: AppConfiguration,
        userDefaults: UserDefaults,
        dismissHandler: @escaping () -> Void
    ) {
        self.dismissHandler = dismissHandler
        self.userDefaults = userDefaults
        do {
            self.completionMessageCount = try Self.getNumberOfMessagesInViewDatabase(with: appConfiguration)
        } catch {
            let migrationError = Beta1MigrationError.couldNotGetCompletionMessageCount
            Log.optional(error, migrationError.localizedDescription)
            CrashReporting.shared.reportIfNeeded(
                error: migrationError,
                metadata: ["underlyingError": error.localizedDescription]
            )
            self.completionMessageCount = 1
        }
    }
    
    /// Wires up our published `progress` property to the statistics service.
    private func bindProgress(to statisticsService: BotStatisticsService) async {
        let statisticsPublisher = await statisticsService.subscribe()
        
        // Wire up peers array to the statisticsService
        statisticsPublisher
            // Ignore the first statistics because the database doesn't get dropped right away
            .dropFirst()
            .map {
                // Calculate completion percentage
                let completionFraction = Float($0.repo.messageCount) / Float(self.completionMessageCount)
                return completionFraction.clamped(to: 0.0...1.0)
            }
            .receive(on: RunLoop.main)
            .sink(receiveValue: { progress in
                self.progress = progress
            })
            .store(in: &self.cancellabes)
    }
    
    /// This opens up a special connection to the SQLLite database and retrieves the total message count.
    /// We duplicate code from `ViewDatabase` on purpose. This way if the `ViewDatabase` schema changes in future
    /// releases this migration will still work in the unlikely event someone updates a very old installation of
    /// Planetary and opens it up.
    private static func getNumberOfMessagesInViewDatabase(with configuration: AppConfiguration) throws -> Int {
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory,
            .userDomainMask,
            true
        )
        
        guard !appSupportDirs.isEmpty else {
            throw GoBotError.unexpectedFault("no support dir")
        }
        
        guard let networkKey = configuration.network else {
            throw GoBotError.unexpectedFault("No network key in configuration.")
        }

        let path = appSupportDirs[0]
            .appending("/FBTT")
            .appending("/\(networkKey.hexEncodedString())")
        
        let dbPath = "\(path)/schema-built\(ViewDatabase.schemaVersion).sqlite"
        let dbConnection = try Connection(dbPath)
        let msgs = Table("messages")
        return try dbConnection.scalar(msgs.count)
    }
    
    // MARK: Handle User Interation
    
    func dismissPressed() {
        userDefaults.set(true, forKey: "CompletedBeta1Migration")
        userDefaults.synchronize()
        cancellabes.forEach { $0.cancel() }
        dismissHandler()
    }
}
