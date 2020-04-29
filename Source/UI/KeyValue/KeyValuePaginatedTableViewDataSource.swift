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
        print("[DEBUG] number of rows: \(self.data.count)")
        return self.data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("[DEBUG] cellForRowAt \(indexPath)")
        guard let keyValue = self.data.keyValueBy(index: indexPath.row, late: self.latePrefetch) else {
            // TODO: return a better in-progress / spinner cell here
            return KeyValueTableViewCell(for: .post)
        }
        let cell = self.dequeueReusuableCell(in: tableView, at: indexPath, for: keyValue)
        cell.update(with: keyValue)
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
    private func latePrefetch(idx: Int, kv: KeyValue) {
        let c = self.cell(at: IndexPath.init(row: idx, section: 0), for: kv.value.content.type)
        c.update(with: kv)
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

    func cell(at indexPath: IndexPath, for type: ContentType) -> KeyValueTableViewCell {
        let view = PostReplyView()
        view.postView.truncationLimit = self.truncationLimitForPost(at: indexPath)
        let cell = KeyValueTableViewCell(for: .post, with: view)
        return cell
    }
    
    private func truncationLimitForPost(at indexPath: IndexPath) -> TruncationSettings? {
        guard let keyValue = self.data.keyValueBy(index: indexPath.row, late: noop) else { return nil }
        guard let post = keyValue.value.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
}

fileprivate let noop: PrefetchCompletion = { _, _ in }
