//
//  URL+Identifier.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension URL {

    var identifier: Identifier? {
        let identifier = self.absoluteString
        if identifier.isValidIdentifier { return identifier }
        else { return nil }
    }
}
