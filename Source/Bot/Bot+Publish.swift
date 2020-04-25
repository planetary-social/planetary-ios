//
//  Bot+Publish.swift
//  FBTT
//
//  Created by Christoph on 7/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

typealias PublishBlobsCompletion = ((Blobs, Error?) -> Void)

extension Bot {

    func publish(_ post: Post,
                 with images: [UIImage] = [],
                 completion: @escaping PublishCompletion)
    {
        //Thread.assertIsMainThread()

        // publish all images first
        self.prepare(images) {
            blobs, error in
            if Log.optional(error) { completion(Identifier.null, error); return }

            // mutate post to include blobs
            let postWithBlobs = post.copy(with: blobs)

            // publish post
            self.publish(content: postWithBlobs) {
                postIdentifier, error in
                if Log.optional(error) { completion(.null, error); return }
                completion(postIdentifier, nil)
            }
        }
    }

    // will attempt to add all images to the blob-store and annotate them with metadata
    // will quit after first failure and return an error without models
    // if some of the images were published and later ones fail well
    // then doing this again will duplicate already published images
    func prepare(_ images: [UIImage],
                 completion: @escaping PublishBlobsCompletion)
    {
        //Thread.assertIsMainThread()
        if images.isEmpty { completion([], nil); return }

        var blobs = [Int: Blob]()

        // TODO need to add Bot.publish(blobs)
        // TODO check all blobs before publish
        let datas = images.compactMap { $0.blobData() }
        // TODO need Bot error
        guard datas.count == images.count else { completion([], nil); return }

        for (index, data) in datas.enumerated() {
            let image = images[index]
            self.addBlob(data: data) {
                identifier, error in
                if let error = error { completion([], error); return }
                let metadata = Blob.Metadata.describing(image, mimeType: .jpeg, data: data)
                let blob = Blob(identifier: identifier, metadata: metadata)
                blobs[index] = blob
                if blobs.count == images.count {
                    let sortedBlobs = blobs.sorted(by: {$0.0 < $1.0})
                    completion(sortedBlobs.map{ $1 }, nil)
                }
            }
        }
    }
}

fileprivate extension UIImage {

    /// Convenience to return data representing the JPG
    /// compressed version of the image.  This assumes
    /// a max size and compression ratio that fits within
    /// the SSB blob max bytes.
    func blobData() -> Data? {
        guard let image = self.resized(toLargestDimension: 1000) else { return nil }
        guard let data = image.jpegData(compressionQuality: 0.5) else { return nil }
        return data
    }
}
