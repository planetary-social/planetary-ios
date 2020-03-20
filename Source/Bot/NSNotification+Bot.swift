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
    static let didSyncAndRefresh = Notification.Name("didSyncAndRefresh")
}


// MARK:- FSCK
extension Notification.Name {
    static let didStartFSCKRepair = Notification.Name("didStartFSCKRepair")
    static let didUpdateFSCKProgress = Notification.Name("didUpdateFSCKProgress")
    static let didFinishFSCKRepair = Notification.Name("didFinishFSCKRepair")
}

extension Notification {
    static func didUpdateFSCKProgress(_ msgs: UInt64) -> Notification {
        return Notification(name: .didUpdateFSCKProgress,
                            object: nil,
                            userInfo: ["messages_left": msgs])
    }
}
