//
//  Identifier.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation

struct Identifier {
    var key: String
    init(key: String? = nil) {
        self.key = key ?? "not-logged-in"
    }
}
