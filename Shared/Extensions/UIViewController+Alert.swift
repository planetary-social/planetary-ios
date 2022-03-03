//
//  UIViewController+Alert.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

protocol AlertRouter {
    
    /// Presents an error message to the user in an alert box.
    /// - Parameter error: The error to present to the user. The `localizedDescription` is used for the error message.
    func alert(error: Error)
}

extension UIViewController: AlertRouter {
    
    /// Presents an error message to the user in an alert box.
    /// - Parameter error: The error to present to the user. The `localizedDescription` is used for the error message.
    func alert(error: Error) {
        let controller = UIAlertController(title: Text.error.text,
                                           message: error.localizedDescription,
                                           preferredStyle: .alert)
        controller.view.tintColor = UIColor.tint.system

        let cancelAction = UIAlertAction(title: Text.cancel.text,
                                         style: .cancel) { _ in
                                            controller.dismiss(animated: true)
        }
        controller.addAction(cancelAction)
        
        self.present(alertController: controller)
    }
    
    /// Presents an alert box to the user with a single button.
    ///
    /// - Parameters:
    ///   - sourceView: The view that the popover arrow should point to on large devices if you would like to display
    ///         the alert as an `.actionSheet`. If this parameter is nil the choices will be displayed in a `.alert`
    ///         style. Should be a subclass of either `UIView` or `UIBarButtonItem`.
    ///   - title: The title of the alert.
    ///   - message: A description shown below the title.
    ///   - cancelTitle: A button that closes the alert.
    ///   - cancelClosure: A closure that will be called with the alert is dismissed.
    func alert(from sourceView: AnyObject? = nil,
               title: String? = nil,
               message: String,
               cancelTitle: String = Text.cancel.text,
               cancelClosure: (() -> Void)? = nil) {
        
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelClosure?()
        }

        self.choose(from: [cancel], title: title, message: message, sourceView: sourceView)
    }
    
    /// Presents a modal dialog prompting the user to confirm an action.
    ///
    /// - Parameters:
    ///   - sourceView: The view that the popover arrow should point to on large devices if you would like to display
    ///         the choices as an `.actionSheet`. If this parameter is nil the choices will be displayed in a `.alert`
    ///         style. Should be a subclass of either `UIView` or `UIBarButtonItem`.
    ///   - title: A title displayed above the confirmation buttons.
    ///   - message: A message displayed with confirmationButtons buttons.
    ///   - isDestructive: Whether or not the action being confirmed is destructive.
    ///   - cancelTitle: The title of the cancel button.
    ///   - cancelClosure: A closure that will be performed if the cancel button is pressed.
    ///   - confirmTitle: The title of the confirmation button.
    ///   - confirmClosure: A closure that will be performed if the confirmation button is pressed.
    func confirm(from sourceView: UIView? = nil,
                 title: String? = nil,
                 message: String,
                 isDestructive: Bool = false,
                 cancelTitle: String = Text.cancel.text,
                 cancelClosure: (() -> Void)? = nil,
                 confirmTitle: String = Text.ok.text,
                 confirmClosure: @escaping (() -> Void)) {
        
        let confirm = UIAlertAction(title: confirmTitle,
                                    style: isDestructive ? .destructive : .default) { _ in
            confirmClosure()
        }

        let cancel = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            cancelClosure?()
        }

        self.choose(from: [confirm, cancel], title: title, message: message, sourceView: sourceView)
    }

    /// Convenience func to present multiple alert actions in an iPhone
    /// and iPad compatible way.  UIAlertController management can be tedious
    /// so this makes it a bit easier, plus provides a thin abstraction
    /// layer future custom UI for alerts and confirmations.
    ///
    /// - Parameters:
    ///   - actions: The action buttons to that the user can choose between.
    ///   - title: A title displayed above the action buttons.
    ///   - message: A message displayed with the action buttons.
    ///   - sourceView: The view that the popover arrow should point to on large devices if you would like to display
    ///         the choices as an `.actionSheet`. If this parameter is nil the choices will be displayed in a `.alert`
    ///         style. Should be a subclass of either `UIView` or `UIBarButtonItem`.
    func choose(from actions: [UIAlertAction],
                title: String? = nil,
                message: String? = nil,
                sourceView: AnyObject? = nil) {
        
        let style: UIAlertController.Style = sourceView != nil ? .actionSheet : .alert
        let controller = UIAlertController(title: title,
                                           message: message,
                                           preferredStyle: style)
        controller.view.tintColor = UIColor.tint.system
        for action in actions { controller.addAction(action) }
        self.present(alertController: controller, sourceView: sourceView)
    }
    
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
