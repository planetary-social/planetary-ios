//
//  TextFieldWithInsets.swift
//  Planetary
//
//  Created by Cassandra Zuria on 10/30/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

final class TextFieldWithInsets: UITextField {
    private let insets: UIEdgeInsets
    
    init(insets: UIEdgeInsets = .defaultText) {
        self.insets = insets
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return rect.inset(by: insets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return rect.inset(by: insets)
    }
}
