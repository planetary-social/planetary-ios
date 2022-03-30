//
//  UITableView+KeyValue.swift
//  FBTT
//
//  Created by Christoph on 4/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITableView {

    /// Convenience function to scroll to the specified KeyValue.
    /// If the table's data source is not a `KeyValueTableViewDataSource`
    /// or not in the collection, nothing happens.
    func scroll(to keyValue: KeyValue,
                scrollPosition: UITableView.ScrollPosition = .top,
                animated: Bool = true) {
        guard let indexPath = self.indexPath(for: keyValue) else { return }
        self.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }

    func scroll(toKeyValueWith key: Identifier,
                scrollPosition: UITableView.ScrollPosition = .top,
                animated: Bool = true) {
        guard let indexPath = self.indexPath(forKeyValueWith: key) else { return }
        self.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }
}
