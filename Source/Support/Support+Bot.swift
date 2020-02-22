//
//  Support+Bot.swift
//  Planetary
//
//  Created by Christoph on 11/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import ZendeskCoreSDK
import ZendeskSDK
import UIKit

extension Support {

    /// Gathers all the related blobs for the specified KeyValue, then asynchronously returns
    /// a view controller with those items attached.
    static func newTicketViewController(reporting post: KeyValue,
                                        reason: Reason,
                                        completion: @escaping ((UIViewController) -> Void))
    {
        Support.requestAttachments(for: post.value.content.post) {
            attachments in
            let tags = [reason.rawValue, post.key, post.value.author]
            let controller = Support.newTicketViewController(subject: .contentReport,
                                                             attachments: attachments,
                                                             tags: tags)
            completion(controller)
        }
    }

    /// Gathers JSON and blobs for the specified Post, and returns then asynchronouosly
    /// as Zendesk RequestAttachments.
    private static func requestAttachments(for post: Post?,
                                           completion: @escaping ((RequestAttachments) -> Void))
    {
        // attach post JSON first
        guard let post = post else { completion([]); return }
        var attachments: RequestAttachments = []
        attachments.add(post.requestAttachment())

        // attach blobs if necessary
        guard let blobs = post.blobs, blobs.count > 0 else { completion(attachments); return }
        Bots.current.blobsAndDatas(for: blobs) {
            blobsAndDatas in
            for (index, blobAndData) in blobsAndDatas.enumerated() {

                // create an attachment from the blob and data
                let attachment = RequestAttachment(filename: blobAndData.0.identifier,
                                                   data: blobAndData.1,
                                                   fileType: .binary)
                attachments += [attachment]

                // call completion on last attachment
                if index == blobsAndDatas.count - 1 {
                    completion(attachments)
                }
            }
        }
    }
}

fileprivate extension Post {

    func requestAttachment() -> RequestAttachment? {
        guard let data = try? self.encodeToData() else { return nil }
        let name = "JSON \(Date().shortDateTimeString)"
        return RequestAttachment(filename: name,
                                 data: data,
                                 fileType: .plain)
    }
}
