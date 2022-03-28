//
//  Logs+Attachable.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import SupportSDK

extension Logs {
    func requestAttachments() -> [RequestAttachment] {
        var attachments = [RequestAttachment]()
        if let data = appLog {
            attachments.append(RequestAttachment(filename: "app_log.txt", data: data, fileType: .plain))
        }
        if let data = botLog {
            attachments.append(RequestAttachment(filename: "bot_log.txt", data: data, fileType: .plain))
        }
        return attachments
    }
}
