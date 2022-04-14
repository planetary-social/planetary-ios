//
//  Author.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation

struct Author {
    var identifier: Identifier
    var name: String?
}

extension Author: Attachable {

    func attachments() -> [Attachment] {
        let nameOrIdentity = name ?? identifier.key
        let data = identifier.key.data(using: .utf8) ?? Data()
        return [Attachment(filename: nameOrIdentity, data: data, type: .plainText)]
    }
}
