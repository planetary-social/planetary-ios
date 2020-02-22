//
//  KeyValueTableViewDataSourcePrefetching.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValueTableViewDataSourcePrefetching: NSObject, UITableViewDataSourcePrefetching {

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard let dataSource = tableView.dataSource as? KeyValueTableViewDataSource else { return }
        let keyValues = dataSource.keyValues(at: indexPaths)
        self.prefetchRows(withKeyValues: keyValues)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        guard let dataSource = tableView.dataSource as? KeyValueTableViewDataSource else { return }
        let keyValues = dataSource.keyValues(at: indexPaths)
        self.cancelPrefetchingForRows(withKeyValues: keyValues)
    }

    func prefetchRows(withKeyValues keyValues: KeyValues) {
        // subclasses are encouraged to override
    }

    func cancelPrefetchingForRows(withKeyValues keyValues: KeyValues) {
        // subclasses are encouraged to override
    }
}
