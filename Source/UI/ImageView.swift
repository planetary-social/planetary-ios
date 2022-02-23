//
//  UIImageView+ImageMetadata.swift
//  FBTT
//
//  Created by Christoph on 5/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ImageView: UIImageView {

    // TODO rename?
    private var identifier: BlobIdentifier?
    private var completion: UUID?

    deinit {
        self.forgetBlobCompletion()
    }

    private func forgetBlobCompletion() {
        guard let identifier = self.identifier else { return }
        guard let uuid = self.completion else { return }
        Caches.blobs.forgetCompletions(with: uuid, for: identifier)
        Caches.blobs.cancelDataTask(for: identifier)
    }

    func set(image: ImageMetadata?, animated: Bool = false) {

        // always forget any pending completion
        self.forgetBlobCompletion()

        // nil image assumes clearing the image
        // this is symmetric with UIImage.setImage()
        guard let image = image else {
            self.image = UIImage.verse.missingAbout
            return
        }

        // cached image
        if let image = Caches.blobs.image(for: image.identifier) {
            if animated { self.fade(to: image) }
            else        { self.image = image }
            return
        }

        // request image
        let uuid = Caches.blobs.image(for: image.identifier) {
            [weak self] _, image in
            if animated { self?.fade(to: image) }
            else        { self?.image = image }
        }

        // wait for completion
        self.completion = uuid
        self.identifier = image.identifier
    }
}
