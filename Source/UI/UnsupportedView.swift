//
//  UnsupportedView.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class UnsupportedView: MessageView {

    let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .lightGray
        return label
    }()

    convenience init() {
        self.init(frame: CGRect.zero)
        self.backgroundColor = .darkGray
        Layout.fill(view: self, with: self.label)
    }

    override func update(with message: Message) {
        let text = "'\(message.contentType.rawValue.capitalized)' is an unsupported content type"
        self.label.text = text
    }
}
