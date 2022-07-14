//
//  HelpDrawerViewController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import SwiftUI
import Analytics

struct HelpCoordinator {
    
    static func helpController(
        for viewController: UIViewController,
        sourceBarButton: UIBarButtonItem
    ) -> UIViewController {
        let view = HelpDrawer(
            tabName: Text.home.text,
            tabImageName: "tab-icon-home",
            helpTitle: Text.Help.Home.title.text,
            bodyText: Text.Help.Home.body.text,
            highlightedWord: Text.Help.Home.highlightedWord.text
        ) {
            viewController.dismiss(animated: true)
        }
        
        let controller = UIHostingController(rootView: view)
        
        controller.modalPresentationStyle = .popover
        controller.modalTransitionStyle = .coverVertical
        if let hostPopover = controller.popoverPresentationController {
            hostPopover.barButtonItem = sourceBarButton
            let sheet = hostPopover.adaptiveSheetPresentationController
            sheet.detents = [.medium()]
            sheet.preferredCornerRadius = 15
        }
        
        Analytics.shared.trackDidShowScreen(screenName: "Home Help Drawer")
        
        return controller
    }
}
