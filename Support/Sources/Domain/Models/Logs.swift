//
//  Logs.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation

struct Logs {
    var appLog: Data?
    var botLog: Data?
}

extension Logs: Attachable {
    func attachments() -> [Attachment] {
        var attachments = [Attachment]()
        if let data = appLog {
            attachments.append(Attachment(filename: "app_log.txt", data: data, type: .plainText))
        }
        if let data = botLog {
            attachments.append(Attachment(filename: "bot_log.txt", data: data, type: .plainText))
        }
        return attachments
    }
}
