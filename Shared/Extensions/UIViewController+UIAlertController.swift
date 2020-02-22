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
    func present(alertController controller: UIAlertController,
                 animated: Bool = true)
    {
        controller.configureBottomCenteredPopover(in: self.view)
        self.present(controller, animated: animated)
    }
}

fileprivate extension UIAlertController {

    // TODO https://app.asana.com/0/0/1138310075737188/f
    /// If a popover is available (because this is on an iPad)
    /// the popover will be configured to be presented from the
    /// bottom center inside the supplied view.  This will make
    /// it appear similar as on iPhones, but this is temporary.
    func configureBottomCenteredPopover(in view: UIView) {
        guard let popover = self.popoverPresentationController else { return }
        popover.sourceView = self.view
        var frame = self.view.bounds
        frame.origin.x = frame.midX
        frame.origin.y = frame.size.height - 1
        frame.size.width = 1
        frame.size.height = 1
        popover.sourceRect = frame
        popover.permittedArrowDirections = []
    }
}
