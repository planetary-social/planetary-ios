//
//  Notification+Keyboard.swift
//  FBTT
//
//  Created by Christoph on 3/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension Notification {

    var keyboardFrameEnd: CGRect? {
        guard let info = self.userInfo else { return nil }
        guard let value = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return nil }
        return value.cgRectValue
    }

    var keyboardAnimationDuration: TimeInterval {
        guard let info = self.userInfo else { return 0 }
        guard let number = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else { return 0 }
        return number.doubleValue
    }

    var keyboardAnimationCurve: UIView.AnimationCurve? {
        guard let info = self.userInfo else { return nil }
        guard let number = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else { return nil }
        return UIView.AnimationCurve(rawValue: number.intValue)
    }
}
