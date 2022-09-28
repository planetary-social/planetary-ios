//
//  MessageTableViewDataSourcePrefetching.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessageTableViewDataSourcePrefetching: NSObject, UITableViewDataSourcePrefetching {

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard let dataSource = tableView.dataSource as? MessageTableViewDataSource else { return }
        let messages = dataSource.messages(at: indexPaths)
        self.prefetchRows(withMessages: messages)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        guard let dataSource = tableView.dataSource as? MessageTableViewDataSource else { return }
        let messages = dataSource.messages(at: indexPaths)
        self.cancelPrefetchingForRows(withMessages: messages)
    }

    func prefetchRows(withMessages messages: Messages) {
        // subclasses are encouraged to override
    }

    func cancelPrefetchingForRows(withMessages messages: Messages) {
        // subclasses are encouraged to override
    }
}
