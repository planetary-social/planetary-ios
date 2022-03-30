//
//  String+IsValid.swift
//  FBTT
//
//  Created by Christoph on 7/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension String {

    var isValidBio: Bool {
        self.count <= 140
    }

    var isValidName: Bool {
        let string = self.withoutSpacesOrNewlines
        return string.count >= 3 && string.count <= 50
    }

    var isValidVerificationCode: Bool {
        let digits = Int(self)
        return digits != nil && self.count == 6
    }
}
