//
//  Identifier+Attachable.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import SupportSDK

extension Identifier {
    func requestAttachment() -> RequestAttachment {
        let data = key.data(using: .utf8) ?? Data()
        return RequestAttachment(filename: "content-identifier",
                                 data: data,
                                 fileType: .plain)
    }
}
