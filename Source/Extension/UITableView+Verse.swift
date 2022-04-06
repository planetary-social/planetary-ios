//
//  UITableView+Verse.swift
//  FBTT
//
//  Created by Christoph on 4/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITableView {

    static func forVerse(style: UITableView.Style = .plain) -> UITableView {
        let view = UITableView(frame: CGRect.zero, style: style)
        view.allowsMultipleSelection = false
        view.allowsSelection = true
        view.backgroundColor = .appBackground
        view.rowHeight = UITableView.automaticDimension
        view.separatorColor = UIColor.clear
        // view.separatorInset = UIEdgeInsets.zero
        view.tableFooterView = UIView()
        view.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        return view
    }

    /// Convenience to add a top separator to the first row of the table.  Strangely
    /// this is not done when setting the table's separator color, so the table header
    /// view is used.  If no color is specified, it will use the current `UITableView.separatorColor`.
    func addSeparatorAsHeaderView(color: UIColor? = nil) {
        let color = color ?? self.separatorColor ?? UIColor.separator.middle
        self.tableHeaderView = Layout.separatorView(color: color)
        self.tableHeaderView?.constrainWidth(to: self)
    }

    /// Convenience func to remove the extra white space at the top of
    /// a grouped table view.
    func hideTableViewHeader() {
        var frame = CGRect.zero
        frame.size.height = .leastNormalMagnitude
        self.tableHeaderView = UIView(frame: frame)
    }

    func scrollToTop(animated: Bool = true) {
        let point = CGPoint(x: 0, y: -self.contentInset.top)
        DispatchQueue.main.async {
            self.setContentOffset(point, animated: animated)
        }
    }

    // This is to solve a problem where the initial rendering of the cells on screen, where some cells were
    // initially not laid out correctly, but scrolling away and back gets them rendering properly.
    // I'm annoyed that this actually works. Started down this path based on https://stackoverflow.com/a/52307396
    // I tried every permutation of these calls to see what is absolutely necessary.
    // It seems to work without `setNeedsLayout`, but everything else is required, and I'm leaving that in "just in case"
    func forceReload() {
        self.reloadData()
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.reloadData()
    }
}
