//
//  UITableViewCell+UIActivityIndicator.swift
//  FBTT
//
//  Created by Christoph on 5/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITableViewCell {

    func showActivityIndicator() {
        guard self.accessoryView as? UIActivityIndicatorView == nil else { return }
        let view = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
        view.startAnimating()
        self.accessoryView = view
        self.detailTextLabel?.text = nil
    }

    func hideActivityIndicator(andShow type: UITableViewCell.AccessoryType = .none) {
        self.accessoryView = nil
        self.accessoryType = type
    }
}
