//
//  Text+Localized.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

extension Text {
    init(_ localized: Localized) {
        self.init(localized.text)
    }
}
