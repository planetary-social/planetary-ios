//
//  UIViewController+Keyboard.swift
//  FBTT
//
//  Created by Christoph on 3/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

protocol KeyboardHandling: class {

    var isKeyboardHandlingEnabled: Bool { get set }

    func setKeyboardTopConstraint(constant: CGFloat,
                                  duration: TimeInterval,
                                  curve: UIView.AnimationCurve)

    func registerForKeyboardNotifications()
    func deregisterForKeyboardNotifications()

    func keyboardWillShow(_ notification: Notification)
    func keyboardWillHide(_ notification: Notification)
}

extension KeyboardHandling where Self: UIViewController {

    func registerForKeyboardNotifications() {
        let center = NotificationCenter.default

        // keyboard will be shown or adjusted
        center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                           object: nil,
                           queue: nil) {
            [weak self] notification in
            self?.keyboardWillShow(notification)
        }

        // keyboard will be hidden
        center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                           object: nil, queue: nil) {
            [weak self] notification in
            self?.keyboardWillHide(notification)
        }
    }

    // TODO https://app.asana.com/0/914798787098068/1129954922323149/f
    // TODO this is broken because the registration returns an observer
    // TODO which needs to be specified in order to remove it
    func deregisterForKeyboardNotifications() {
        let center = NotificationCenter.default
        center.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        center.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.keyboardFrameEnd else { return }
        self.setKeyboardTopConstraint(constant: -frame.height,
                                      duration: notification.keyboardAnimationDuration,
                                      curve: notification.keyboardAnimationCurve ?? .linear)
    }

    func keyboardWillHide(_ notification: Notification) {
        self.setKeyboardTopConstraint(constant: 0,
                                      duration: notification.keyboardAnimationDuration,
                                      curve: notification.keyboardAnimationCurve ?? .linear)
    }
}
