//
//  UIViewController+UIAlertController.swift
//  FBTT
//
//  Created by Christoph on 9/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    /// Convenience extension to allow UIAlertController to be presented
    /// on iPads.
    /// - Parameters:
    ///   - controller: The controller that will be presented
    ///   - sourceView: The view that the popover arrow should point to on large devices if this is an action sheet
    ///      alert. Should be a subclass of either `UIView` or `UIBarButtonItem`. This property is required if the
    ///      alert style is `.actionSheet` and is ignored otherwise.
    ///   - sourceRect: The rectangle in the coordinate space of sourceView that the popover should point at. This
    ///      property is ignored if sourceView is a `UIBarButtonItem`.
    ///   - animated: Whether or not the transition should be animated.
    func present(alertController controller: UIAlertController,
                 sourceView: AnyObject? = nil,
                 sourceRect: CGRect? = nil,
                 animated: Bool = true) {

        

        if controller.preferredStyle == .actionSheet && sourceView == nil {
            let errorMessage = "sourceView is required to present a popover controller"
            Log.error(errorMessage)
            assertionFailure(errorMessage)
        }
        
        controller.configurePopover(from: sourceView, rect: sourceRect)
        present(controller, animated: animated)
    }
    
    /// Configures the UIViewController to be presented from the correct source location when it is displayed in a
    /// popover.
    /// - Parameter sourceView: the view that the popover arrow should point to. Should be a subclass of either
    ///     `UIView` or `UIBarButtonItem`
    /// - Parameter rect: The rectangle in the coordinate space of sourceView that the popover should point at. This
    ///      property is ignored if sourceView is a `UIBarButtonItem`.
    func configurePopover(from sourceView: AnyObject?, rect: CGRect? = nil) {
        guard let popover = self.popoverPresentationController,
              let sourceView = sourceView else {
                  return
        }
        
        let sourceUIView = sourceView as? UIView
        let sourceBarButton = sourceView as? UIBarButtonItem
        
        popover.sourceView = sourceUIView
        popover.barButtonItem = sourceBarButton
        if let rect = rect ?? sourceView.bounds {
            popover.sourceRect = rect
        }
    }
}
