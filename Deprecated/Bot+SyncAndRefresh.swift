//
//  Created by Christoph on 5/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Bot {

    typealias SyncAndRefreshCompletion = ((Int, Error?) -> Void)

    // TODO deprecate so sync and refresh are used separately?
    /// This is provided as a convenience for places where the
    /// peer sync should be immediately followed by a view
    /// database refresh.  If the current bot is already
    /// syncing or redfreshing, this will return immediately
    /// without error.
    @available(*, deprecated)
    func syncAndRefresh(completion: SyncAndRefreshCompletion? = nil) {

        assert(Thread.isMainThread)
        guard let _ = self.identity else { completion?(-1, BotError.notLoggedIn); return }

        self.sync {
            error, _, numberOfMessages in
            if let error = error {
                Log.unexpected(.botError, "failed to sync with pubs")
                Log.optional(error)
            }
            self.refresh {
                error, _ in
                completion?(numberOfMessages, error)
                NotificationCenter.default.post(name: .didSyncAndRefresh, object: nil)
            }
        }
    }
}
