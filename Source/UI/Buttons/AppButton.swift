//
//  AppButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

// a generic button class that provides tap functionality and basic setup, but no visual styling
class AppButton: UIButton {

    // an assignable action that a user of the button can use to customize behavior
    // if not assigned, the defaultAction provided by the class will be called instead.
    var action: ((AnyObject) -> Void)?

    init() {
        super.init(frame: .zero)
        self.useAutoLayout()

        self.addTarget(self, action: #selector(didPress), for: .touchUpInside)
    }

    // allows the button class to implement a default action, if no additional context is needed to perform the action
    // otherwise, assign `action`.
    func defaultAction() {
        assertionFailure("Default action was not implemented.")
    }

    @objc func didPress(sender: AnyObject) {
        if let action = self.action {
            action(sender)
        } else {
            self.defaultAction()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
