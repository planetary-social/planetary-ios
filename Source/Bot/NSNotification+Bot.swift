//
//  NSNotification+Bot.swift
//  Planetary
//
//  Created by Christoph on 11/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// MARK:- Blocking

extension Notification.Name {
    static let didBlockUser = Notification.Name("didBlockUser")
    static let didUnblockUser = Notification.Name("didUnblockUser")
}

// MARK:- Blobs

extension Notification.Name {
    static let didLoadBlob = Notification.Name("didLoadBlob")
}

extension Notification {

    var blobIdentifier: BlobIdentifier? {
        return self.userInfo?["blobIdentifier"] as? BlobIdentifier
    }

    static func didLoadBlob(_ identifier: BlobIdentifier) -> Notification {
        return Notification(name: .didLoadBlob,
                            object: nil,
                            userInfo: ["blobIdentifier": identifier])
    }
}

// MARK:- Sync and refresh

// TODO https://app.asana.com/0/914798787098068/1154847034386753/f
// TODO didRefresh should be deprecated
// TODO and we should flatten into a single didSync for both operations
extension Notification.Name {
    static let didRefresh = Notification.Name("didRefresh")
    static let didSync = Notification.Name("didSync")
}


// MARK:- Databae progress
extension Notification.Name {
    static let didStartDatabaseProcessing = Notification.Name("didStartDatabaseProcessing")
    static let didUpdateDatabaseProgress = Notification.Name("didUpdateDatabaseProgress")
    static let didFinishDatabaseProcessing = Notification.Name("didFinishDatabaseProcessing")
}

extension Notification {

    var databaseProgressPercentageDone: Float64? {
        return self.userInfo?["percentage_done"] as? Float64
    }
    
    var databaseProgressStatus: String? {
        return self.userInfo?["status"] as? String
    }
    
    static func didStartFSCKRepair() -> Notification {
        return Notification(name: .didStartDatabaseProcessing,
                            object: nil,
                            userInfo: [ "status": "Database consistency check in progress" ])
    }

    static func didStartViewRefresh() -> Notification {
        return Notification(name: .didStartDatabaseProcessing,
                            object: nil,
                            userInfo: [ "status": "Loading new messages" ])
    }

    static func didUpdateDatabaseProgress(perc: Float64, status: String) -> Notification {
        return Notification(name: .didUpdateDatabaseProgress,
                            object: nil,
                            userInfo: ["percentage_done": perc, "status": status])
    }
}
