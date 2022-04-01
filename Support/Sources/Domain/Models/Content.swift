//
//  Content.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation

struct Content {
    var identifier: Identifier
    var author: Author
    var screenshot: Data?
}

extension Content: Attachable {

    func attachments() -> [Attachment] {
        var attachments = [Attachment]()
        if let data = screenshot {
            let date = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .short,
                timeStyle: .short
            )
            let attachment = Attachment(filename: date, data: data, type: .jpg)
            attachments.append(attachment)
        }
        attachments.append(contentsOf: author.attachments())
        attachments.append(contentsOf: identifier.attachments())
        return attachments
    }

}
