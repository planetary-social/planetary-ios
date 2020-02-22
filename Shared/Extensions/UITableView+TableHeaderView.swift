//
//  UITableView+TableHeaderView.swift
//  FBTT
//
//  Created by Christoph on 4/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITableView {

    /// Convenience function to set and constrain a view as the
    /// table header view.  Callers are still responsible for asking
    /// the view to `layoutIfNeeded()` if the instrinsic content size
    /// changes.
    ///
    /// IMPORTANT!
    /// To ensure that the specified view is auto-layed out correctly
    /// in relation to the other table view cells, it is recommended
    /// to set this during `UIViewController.viewDidLayoutSubviews()`.
    /// This does not cause multiple or overlapping constraints and
    /// seems to work well.
    func setTableHeaderView(_ view: UIView) {
        self.tableHeaderView = view
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        view.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    }
}
