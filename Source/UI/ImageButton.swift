//
//  UIButton+Image.swift
//  FBTT
//
//  Created by Christoph on 6/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class ImageButton: UIButton {

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

    /// Sets the image for the specified state from the `BlobCache`.
    /// If the cached image is not ready, then the image is set when
    /// the cache returns a response.  Note that this means whatever
    /// image is currently set will remain until the cache returns.
    func set(image: Image?,
             for state: UIControl.State = .normal)
    {
        // always forget any pending completion
        self.forgetBlobCompletion()

        // nil image assumes clearing the image
        guard let image = image else {
            self.setImage(nil, for: state)
            return
        }

        // cached image
        if let image = Caches.blobs.image(for: image.identifier) {
            self.setImage(image, for: state)
            return
        }

        // request image
        let uuid = Caches.blobs.imageOrPlaceholder(for: image.identifier) { [weak self] image in
            self?.setImage(image, for: state)
        }

        // wait for completion
        self.completion = uuid
        self.identifier = image.identifier
    }
}
