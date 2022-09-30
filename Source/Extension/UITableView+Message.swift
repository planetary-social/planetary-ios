//
//  UITableView+Message.swift
//  FBTT
//
//  Created by Christoph on 4/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITableView {

    /// Convenience function to scroll to the specified Message.
    /// If the table's data source is not a `MessageTableViewDataSource`
    /// or not in the collection, nothing happens.
    func scroll(to message: Message,
                scrollPosition: UITableView.ScrollPosition = .top,
                animated: Bool = true) {
        guard let indexPath = self.indexPath(for: message) else { return }
        self.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }

    func scroll(toMessageWith key: Identifier,
                scrollPosition: UITableView.ScrollPosition = .top,
                animated: Bool = true) {
        guard let indexPath = self.indexPath(forMessageWith: key) else { return }
        self.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
    }
}
