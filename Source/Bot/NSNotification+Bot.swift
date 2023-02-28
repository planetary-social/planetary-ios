//
//  NSNotification+Bot.swift
//  Planetary
//
//  Created by Christoph on 11/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// MARK: - Blocking

extension Notification.Name {
    static let didBlockUser = Notification.Name("didBlockUser")
    static let didUnblockUser = Notification.Name("didUnblockUser")
}

// MARK: - Blobs

extension Notification.Name {
    static let didLoadBlob = Notification.Name("didLoadBlob")
}

extension Notification {

    var blobIdentifier: BlobIdentifier? {
        self.userInfo?["blobIdentifier"] as? BlobIdentifier
    }

    static func didLoadBlob(_ identifier: BlobIdentifier) -> Notification {
        Notification(
            name: .didLoadBlob,
            object: nil,
            userInfo: ["blobIdentifier": identifier]
        )
    }
}

// MARK: - Sync and refresh

extension Notification.Name {
    static let didRefresh = Notification.Name("didRefresh")
    static let didSync = Notification.Name("didSync")
    static let didChangeHomeFeedAlgorithm = Notification.Name("didChangeHomeFeedAlgorithm")
    static let didChangeDiscoverFeedAlgorithm = Notification.Name("didChangeDiscoverFeedAlgorithm")
    static let didUpdateReportReadStatus = Notification.Name("didUpdateReportReadStatus")
}

// MARK: - Database progress
extension Notification.Name {
    static let didCreateReport = Notification.Name("didCreateReport")
}

// MARK: - Bot migration
extension Notification.Name {
    static let migrationOnRunning = Notification.Name("migrationOnRunning")
    static let migrationOnError = Notification.Name("migrationOnError")
    static let migrationOnDone = Notification.Name("migrationOnDone")
}
