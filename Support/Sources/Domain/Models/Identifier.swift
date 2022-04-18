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

extension Identifier: Attachable {
    func attachments() -> [Attachment] {
        let data = key.data(using: .utf8) ?? Data()
        return [Attachment(filename: "content-identifier", data: data, type: .plainText)]
    }
}
