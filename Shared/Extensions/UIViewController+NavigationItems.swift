//
//  UIViewController+NavigationItems.swift
//  FBTT
//
//  Created by Zef Houssney on 9/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

extension UIViewController {

    func removeBackItemText() {
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
    func addDismissBarButtonItem() {
        let item = UIBarButtonItem(image: UIImage.verse.dismiss, style: .plain, target: self, action: #selector(didPressDismiss))
        item.accessibilityLabel = Text.done.text
        self.navigationItem.leftBarButtonItem = item
    }

    @objc func didPressDismiss() {
        Analytics.shared.trackDidTapButton(buttonName: "cancel")
        self.dismiss(animated: true, completion: nil)
    }
}
