//
//  Author+Attachable.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import SupportSDK

extension Author {
    func requestAttachment() -> RequestAttachment {
        let nameOrIdentity = name ?? identifier.key
        let data = identifier.key.data(using: .utf8) ?? Data()
        return RequestAttachment(filename: nameOrIdentity,
                                 data: data,
                                 fileType: .plain)
    }
}
