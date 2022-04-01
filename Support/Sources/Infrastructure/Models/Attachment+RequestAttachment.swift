//
//  Attachment+RequestAttachment.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import SupportSDK

extension Attachment {

    var requestAttachment: RequestAttachment {
        var fileType: FileType
        switch type {
        case .plainText:
            fileType = .plain
        case .jpg:
            fileType = .jpg
        }
        return RequestAttachment(
            filename: filename,
            data: data,
            fileType: fileType)
    }
}
