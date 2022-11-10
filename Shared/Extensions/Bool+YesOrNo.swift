//
//  Bool+YesOrNo.swift
//  FBTT
//
//  Created by Christoph on 8/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Bool {
    var yesOrNo: String {
        self ? Localized.yes.text : Localized.no.text
    }
}
