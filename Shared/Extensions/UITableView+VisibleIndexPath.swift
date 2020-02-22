//
//  UITableView+VisibleIndexPath.swift
//  FBTT
//
//  Created by Christoph on 7/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// TODO https://app.asana.com/0/914798787098068/1129954922323146/f
// TODO When only two partial replies are visible, showing keyboard does not scroll to the correct row
extension UITableView {

    /// Based on `UITableView.rectForRow(at)`, returns a rect representing
    /// the frame of the row in the table view's superview coordinate system.
    /// This is useful in determining how much of a row is visible.
    func convertedFrameForRow(at indexPath: IndexPath) -> CGRect {
        guard let superview = self.superview else { return .zero }
        let rect = self.rectForRow(at: indexPath)
        let frame = self.convert(rect, to: superview)
        return frame
    }

    /// Returns an index path for the last visible row.  `percentVisible` allows
    /// tuning how much of the row is visible to be considered the "last visible row".
    /// By default the row must be 100% visible, but can be tuned as needed.
    /// The table view must be in a view hierarchy and must have visible rows
    /// for this to return a non-optional value.
    func indexPathForLastVisibleRow(percentVisible: CGFloat = 1.0) -> IndexPath? {

        // the table view must be in a hierarchy and must have visible rows
        guard self.superview != nil else { return nil }
        guard let indexPaths = self.indexPathsForVisibleRows else { return nil }
        for indexPath in indexPaths.reversed() {

            // calculate the amount of intersection
            // if higher or equivalent to the required, this is your row
            let frame = self.convertedFrameForRow(at: indexPath)
            let intersection = self.frame.intersection(frame)
            let intersectionPercentage = intersection.height / frame.height
            if intersectionPercentage >= percentVisible { return indexPath }
        }

        // if this far the no matching row
        return nil
    }
}
