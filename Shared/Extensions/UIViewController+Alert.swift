//
//  UIViewController+Alert.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

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
    
    func alert(style: UIAlertController.Style = .actionSheet,
               title: String? = nil,
               message: String,
               cancelTitle: String = Text.cancel.text,
               cancelClosure: (() -> Void)? = nil)
    {
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel) {
            _ in
            cancelClosure?()
        }

        self.choose(from: [cancel], style: style, title: title, message: message)
    }

    func confirm(style: UIAlertController.Style = .actionSheet,
                 title: String? = nil,
                 message: String,
                 isDestructive: Bool = false,
                 cancelTitle: String = Text.cancel.text,
                 cancelClosure: (() -> Void)? = nil,
                 confirmTitle: String = Text.ok.text,
                 confirmClosure: @escaping (() -> Void))
    {
        let confirm = UIAlertAction(title: confirmTitle,
                                    style: isDestructive ? .destructive : .default)
        {
            _ in
            confirmClosure()
        }

        let cancel = UIAlertAction(title: cancelTitle, style: .cancel) {
            _ in
            cancelClosure?()
        }

        self.choose(from: [confirm, cancel], style: style, title: title, message: message)
    }

    /// Convenience func to present multiple alert actions in an iPhone
    /// and iPad compatible way.  UIAlertController management can be tedious
    /// so this makes it a bit easier, plus provides a thin abstraction
    /// layer future custom UI for alerts and confirmations.
    func choose(from actions: [UIAlertAction],
                style: UIAlertController.Style = .actionSheet,
                title: String? = nil,
                message: String? = nil)
    {
        let controller = UIAlertController(title: title,
                                           message: message,
                                           preferredStyle: style)
        controller.view.tintColor = UIColor.tint.system
        for action in actions { controller.addAction(action) }
        self.present(alertController: controller)
    }
}
