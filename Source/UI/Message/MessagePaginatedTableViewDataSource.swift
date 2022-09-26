//
//  MessagePaginatedTableViewDataSource.swift
//  Planetary
//
//  Created by H on 21.04.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

// wild copy pasta from the PostView table datasource
// this implements prefetching using a proxy

class MessagePaginatedTableViewDataSource: NSObject, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    var data: PaginatedMessageDataProxy = StaticDataProxy()

    func update(source: PaginatedMessageDataProxy) {
        self.data = source
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let latePrefetch = { [weak tableView] (idx: Int, _: Message) -> Void in
            DispatchQueue.main.async { [weak tableView] in
                let indexPath = IndexPath(item: idx, section: 0)
                tableView?.reloadRows(at: [indexPath], with: .fade)
            }
        }
        guard let message = self.data.messageBy(index: indexPath.row, late: latePrefetch) else {
            return emptyCell()
        }
        let cell = self.dequeueReusuableCell(in: tableView, at: indexPath, for: message)
        self.loadMessage(message, in: cell)
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
//        self.loadMessage(kv, in: c)
    }

    // more copy pasta
    
    /// This is purposefully not public as no subclass should need to override
    /// the resuable cell dequeue process.  If a different type of cell is needed,
    /// override `cell(for: type)` instead.
    private func dequeueReusuableCell(in tableView: UITableView,
                                     at indexPath: IndexPath,
                                     for message: Message) -> MessageTableViewCell {
        let type = message.value.content.type
        let cell = tableView.dequeueReusableCell(withIdentifier: type.reuseIdentifier) as? MessageTableViewCell
        return cell ?? self.cell(at: indexPath, for: type)
    }

    /// Convenience function to return a `MessageTableViewCell` instance
    /// for the specified `ContentType`.  Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func cell(at indexPath: IndexPath, for type: ContentType) -> MessageTableViewCell {
        switch type {
        case .post:
            return MessageTableViewCell(for: type, height: 300)
        case .contact:
            return MessageTableViewCell(for: type, height: 300)
        default:
            return MessageTableViewCell(for: type)
        }
    }
    
    /// Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func emptyCell() -> MessageTableViewCell {
        MessageTableViewCell(for: .post)
    }
    
    func loadMessage(_ message: Message, in cell: MessageTableViewCell) {
        cell.update(with: message)
    }
}

let noop: PrefetchCompletion = { _, _ in }
