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
        Notification(name: .didLoadBlob,
                            object: nil,
                            userInfo: ["blobIdentifier": identifier])
    }
}

// MARK: - Sync and refresh

// TODO https://app.asana.com/0/914798787098068/1154847034386753/f
// TODO didRefresh should be deprecated
// TODO and we should flatten into a single didSync for both operations
extension Notification.Name {
    static let didRefresh = Notification.Name("didRefresh")
    static let didSync = Notification.Name("didSync")
    static let didChangeHomeFeedAlgorithm = Notification.Name("didChangeHomeFeedAlgorithm")
}

// MARK: - Databae progress
extension Notification.Name {
    static let didStartFSCKRepair = Notification.Name("didStartFSCKRepair")
    static let didUpdateFSCKRepair = Notification.Name("didUpdateFSCKRepair")
    static let didFinishFSCKRepair = Notification.Name("didFinishFSCKRepair")
    static let didCreateReport = Notification.Name("didCreateReport")
}

extension Notification {

    var databaseProgressPercentageDone: Float64? {
        self.userInfo?["percentage_done"] as? Float64
    }
    
    var databaseProgressStatus: String? {
        self.userInfo?["status"] as? String
    }
    
    static func didStartFSCKRepair() -> Notification {
        Notification(name: .didStartFSCKRepair,
                            object: nil,
                            userInfo: [ "status": "Database consistency check in progress" ])
    }
    
    static func didFinishFSCKRepair() -> Notification {
        Notification(name: .didFinishFSCKRepair,
                            object: nil)
    }

    static func didUpdateFSCKRepair(perc: Float64, status: String) -> Notification {
        Notification(name: .didUpdateFSCKRepair,
                            object: nil,
                            userInfo: ["percentage_done": perc, "status": status])
    }
}
