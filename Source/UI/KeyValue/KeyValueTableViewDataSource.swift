//
//  UITableView+KeyValue.swift
//  FBTT
//
//  Created by Christoph on 4/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValueTableViewDataSource: NSObject, UITableViewDataSource {

    var keyValues: KeyValues = []

    func keyValue(at indexPath: IndexPath) -> KeyValue {
        self.keyValues[indexPath.row]
    }

    func keyValues(at indexPaths: [IndexPath]) -> KeyValues {
        let indexes = indexPaths.map { $0.row }
        let keyValues = self.keyValues.elements(at: indexes)
        return keyValues
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    /// Returns the number of items in the `keyValues` store.  Subclasses can
    /// override to allow for multiple sections.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.keyValues.count
    }

    /// The typical `UITableViewCell` factory function, tied to the `keyValues` store.
    /// Subclasses should not need to override this unless they need to do specific
    /// things with the returned instance related to the `indexPath`.
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let keyValue = self.keyValue(at: indexPath)
        let cell = self.dequeueReusuableCell(in: tableView, at: indexPath, for: keyValue)
        cell.update(with: keyValue)
        return cell
    }

    /// This is purposefully not public as no subclass should need to override
    /// the resuable cell dequeue process.  If a different type of cell is needed,
    /// override `cell(for: type)` instead.
    private func dequeueReusuableCell(in tableView: UITableView,
                                      at indexPath: IndexPath,
                                      for keyValue: KeyValue) -> KeyValueTableViewCell {
        let type = keyValue.value.content.type
        let cell = tableView.dequeueReusableCell(withIdentifier: type.reuseIdentifier) as? KeyValueTableViewCell
        return cell ?? self.cell(at: indexPath, for: type, tableView: tableView)
    }

    /// Convenience function to return a `KeyValueTableViewCell` instance
    /// for the specified `ContentType`.  Subclasses are encouraged to override
    /// if a dfferent cell is required for their use case.
    func cell(at indexPath: IndexPath,
              for type: ContentType,
              tableView: UITableView) -> KeyValueTableViewCell {
        switch type {
            case .post:     return KeyValueTableViewCell(for: type, height: 300)
            default:        return KeyValueTableViewCell(for: type)
        }
    }

    func deleteKeyValues(at indexPaths: [IndexPath]) {
        let rows = indexPaths.compactMap { $0.row }
        for index in rows.reversed() {
            self.keyValues.remove(at: index)
        }
    }
}

// MARK: - ContentType to be used as a UITableViewCell reuse identifier

extension ContentType {
    var reuseIdentifier: String {
        self.rawValue
    }
}

// MARK: - UITableView support for KeyValueTableViewDataSource

/// Convenience functions to transform between KeyValues and index paths.
/// This works for single-dimension KeyValue arrays, but if that is changed
/// then these funcs will need to overridden.
extension UITableView {

    var keyValueDataSource: KeyValueTableViewDataSource? {
        self.dataSource as? KeyValueTableViewDataSource
    }

    func keyValue(for indexPath: IndexPath) -> KeyValue? {
        guard let source = self.keyValueDataSource else { return nil }
        return source.keyValue(at: indexPath)
    }

    func indexPath(for keyValue: KeyValue) -> IndexPath? {
        guard let source = self.keyValueDataSource else { return nil }
        guard let index = source.keyValues.firstIndex(of: keyValue) else { return nil }
        let indexPath = IndexPath(item: index, section: 0)
        return indexPath
    }

    func indexPath(forKeyValueWith key: Identifier) -> IndexPath? {
        guard let source = self.keyValueDataSource else { return nil }
        guard let index = source.keyValues.firstIndex(where: { $0.key == key }) else { return nil }
        let indexPath = IndexPath(item: index, section: 0)
        return indexPath
    }

    func indexPaths(forKeyValuesBy author: Identity) -> [IndexPath] {
        guard let source = self.keyValueDataSource else { return [] }
        let keyValues = source.keyValues.filter { $0.value.author == author }
        let indexPaths = keyValues.compactMap { self.indexPath(for: $0) }
        return indexPaths
    }
}

// MARK: - Deleting rows and KeyValues

extension UITableView {

    func deleteKeyValues(by author: Identity) {

        // clean up data source key values
        let indexPaths = self.indexPaths(forKeyValuesBy: author)
        guard indexPaths.count > 0 else { return }
        self.keyValueDataSource?.deleteKeyValues(at: indexPaths)

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
