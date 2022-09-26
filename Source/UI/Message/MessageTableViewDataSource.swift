//
//  MessageTableViewDataSource.swift
//  FBTT
//
//  Created by Christoph on 4/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessageTableViewDataSource: NSObject, UITableViewDataSource {

    var messages: Messages = []

    func message(at indexPath: IndexPath) -> Message {
        self.messages[indexPath.row]
    }

    func messages(at indexPaths: [IndexPath]) -> Messages {
        let indexes = indexPaths.map { $0.row }
        let messages = self.messages.elements(at: indexes)
        return messages
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    /// Returns the number of items in the `messages` store.  Subclasses can
    /// override to allow for multiple sections.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.messages.count
    }

    /// The typical `UITableViewCell` factory function, tied to the `messages` store.
    /// Subclasses should not need to override this unless they need to do specific
    /// things with the returned instance related to the `indexPath`.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = self.message(at: indexPath)
        let cell = self.dequeueReusuableCell(in: tableView, at: indexPath, for: message)
        cell.update(with: message)
        return cell
    }

    /// This is purposefully not public as no subclass should need to override
    /// the resuable cell dequeue process.  If a different type of cell is needed,
    /// override `cell(for: type)` instead.
    private func dequeueReusuableCell(
        in tableView: UITableView,
        at indexPath: IndexPath,
        for message: Message
    ) -> MessageTableViewCell {
        let type = message.value.content.type
        let cell = tableView.dequeueReusableCell(withIdentifier: type.reuseIdentifier) as? MessageTableViewCell
        return cell ?? self.cell(at: indexPath, for: type, tableView: tableView)
    }

    /// Convenience function to return a `MessageTableViewCell` instance
    /// for the specified `ContentType`.  Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func cell(at indexPath: IndexPath, for type: ContentType, tableView: UITableView) -> MessageTableViewCell {
        switch type {
        case .post:
            return MessageTableViewCell(for: type, height: 300)
        case .contact:
            return MessageTableViewCell(for: type, height: 300)
        default:
            return MessageTableViewCell(for: type)
        }
    }

    func deleteMessages(at indexPaths: [IndexPath]) {
        let rows = indexPaths.compactMap { $0.row }
        for index in rows.reversed() {
            self.messages.remove(at: index)
        }
    }
}

// MARK: - ContentType to be used as a UITableViewCell reuse identifier

extension ContentType {
    var reuseIdentifier: String {
        self.rawValue
    }
}

// MARK: - UITableView support for MessageTableViewDataSource

/// Convenience functions to transform between Messages and index paths.
/// This works for single-dimension Message arrays, but if that is changed
/// then these funcs will need to overridden.
extension UITableView {

    var messageDataSource: MessageTableViewDataSource? {
        self.dataSource as? MessageTableViewDataSource
    }

    func message(for indexPath: IndexPath) -> Message? {
        guard let source = self.messageDataSource else { return nil }
        return source.message(at: indexPath)
    }

    func indexPath(for message: Message) -> IndexPath? {
        guard let source = self.messageDataSource else { return nil }
        guard let index = source.messages.firstIndex(of: message) else { return nil }
        let indexPath = IndexPath(item: index, section: 0)
        return indexPath
    }

    func indexPath(forMessageWith key: Identifier) -> IndexPath? {
        guard let source = self.messageDataSource else { return nil }
        guard let index = source.messages.firstIndex(where: { $0.key == key }) else { return nil }
        let indexPath = IndexPath(item: index, section: 0)
        return indexPath
    }

    func indexPaths(forMessagesBy author: Identity) -> [IndexPath] {
        guard let source = self.messageDataSource else { return [] }
        let messages = source.messages.filter { $0.value.author == author }
        let indexPaths = messages.compactMap { self.indexPath(for: $0) }
        return indexPaths
    }
}

// MARK: - Deleting rows and Messages

extension UITableView {

    func deleteMessages(by author: Identity) {

        // clean up data source messages
        let indexPaths = self.indexPaths(forMessagesBy: author)
        guard !indexPaths.isEmpty else { return }
        self.messageDataSource?.deleteMessages(at: indexPaths)

        // if the table view is in a view controller that is not
        // on the top of the stack, then trying to animate it will
        // throw a warning, so check for a window first
        guard self.window != nil else {
            self.reloadData()
            return
        }

        // otherwise the table view is visible and has a window
        // so an animation is allowed
        self.performBatchUpdates({
            self.deleteRows(at: indexPaths, with: .automatic)
        })
    }
}
