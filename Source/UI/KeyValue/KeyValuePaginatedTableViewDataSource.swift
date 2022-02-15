//
//  KeyValuePaginatedTableViewDataSource.swift
//  Planetary
//
//  Created by H on 21.04.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit


// wild copy pasta from the PostView table datasource
// this implements prefetching using a proxy

class KeyValuePaginatedTableViewDataSource: NSObject, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    var data: PaginatedKeyValueDataProxy = StaticDataProxy()

    func update(source: PaginatedKeyValueDataProxy) {
        self.data = source
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let latePrefetch = { [weak tableView] (idx: Int, keyValue: KeyValue) -> Void in
            DispatchQueue.main.async { [weak tableView] in
                let indexPath = IndexPath(item: idx, section: 0)
                tableView?.reloadRows(at: [indexPath], with: .fade)
            }
        }
        guard let keyValue = self.data.keyValueBy(index: indexPath.row, late: latePrefetch) else {
            return emptyCell()
        }
        let cell = self.dequeueReusuableCell(in: tableView, at: indexPath, for: keyValue)
        self.loadKeyValue(keyValue, in: cell)
        return cell
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if let biggest = indexPaths.max()?.row {
            // prefetch everything up to the last row
            self.data.prefetchUpTo(index: biggest)
        }
    }

    // ignore cancels since we cant stop running querys anyhow
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) { }

    // have a way get data from prefetches that were too late
    func latePrefetch(idx: Int) {
//
//        let c = self.cell(at: IndexPath.init(row: idx, section: 0), for: kv.value.content.type)
//        self.loadKeyValue(kv, in: c)
    }

    // more copy pasta
    
    /// This is purposefully not public as no subclass should need to override
    /// the resuable cell dequeue process.  If a different type of cell is needed,
    /// override `cell(for: type)` instead.
    private func dequeueReusuableCell(in tableView: UITableView,
                                     at indexPath: IndexPath,
                                     for keyValue: KeyValue) -> KeyValueTableViewCell
    {
        let type = keyValue.value.content.type
        let cell = tableView.dequeueReusableCell(withIdentifier: type.reuseIdentifier) as? KeyValueTableViewCell
        return cell ?? self.cell(at: indexPath, for: type)
    }

    /// Convenience function to return a `KeyValueTableViewCell` instance
    /// for the specified `ContentType`.  Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func cell(at indexPath: IndexPath, for type: ContentType) -> KeyValueTableViewCell {
        switch type {
            case .post:     return KeyValueTableViewCell(for: type, height: 300)
            default:        return KeyValueTableViewCell(for: type)
        }
    }
    
    /// Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func emptyCell() -> KeyValueTableViewCell {
        return KeyValueTableViewCell(for: .post)
    }
    
    func loadKeyValue(_ keyValue: KeyValue, in cell: KeyValueTableViewCell) {
        cell.update(with: keyValue)
    }
    
}

let noop: PrefetchCompletion = { _, _ in }
