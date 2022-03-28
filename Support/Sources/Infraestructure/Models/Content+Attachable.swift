//
//  File.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import SupportSDK

extension Content {

    func requestAttachments() -> [RequestAttachment] {
        var attachments: [RequestAttachment] = []
        if let data = screenshot {
            let date = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .short,
                timeStyle: .short
            )
            let attachment = RequestAttachment(filename: date, data: data, fileType: .jpg)
            attachments.append(attachment)
        }
        attachments.append(author.requestAttachment())
        attachments.append(identifier.requestAttachment())
        return attachments
    }
    
}
