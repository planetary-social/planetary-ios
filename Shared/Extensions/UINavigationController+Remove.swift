//
//  UINavigationController+Remove.swift
//  Planetary
//
//  Created by Christoph on 11/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationController {

    /// Convenience to remove the specified view controller from the stack.  If it is the top
    /// view controller, then it will use UINavigationController.popViewController().  Otherwise
    /// it will remove the view controller by index.
    func remove(viewController: UIViewController, animated: Bool = true) {

        // pop if the top view controller
        if viewController.isTopViewController {
            self.popViewController(animated: animated)
        }

        // otherwise find the index of the view controller and remove
        else {
            guard let index = self.viewControllers.firstIndex(of: viewController) else { return }
            self.viewControllers.remove(at: index)
        }
    }
}
