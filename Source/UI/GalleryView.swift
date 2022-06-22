//
//  GalleryView.swift
//  FBTT
//
//  Created by Christoph on 9/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import ImageSlideshow
import Logger
import UIKit

class GalleryView: UIView, KeyValueUpdateable {

    private let slideshow: ImageSlideshow = {
        let view = ImageSlideshow.forAutoLayout()
        view.backgroundColor = UIColor.cardBackground
        view.circular = true
        view.contentScaleMode = .scaleAspectFill
        view.pageIndicator = UIPageControl.default()
        view.preload = .all
        view.activityIndicator = DefaultActivityIndicator(
            style: UIActivityIndicatorView.Style.medium,
            color: UIColor.loadingIcon
        )
        return view
    }()

    // MARK: Lifecycle

    init(insets: UIEdgeInsets = .zero) {
        super.init(frame: .zero)
        Layout.addSeparator(toTopOf: self.slideshow, color: UIColor.separator.top)
        Layout.fill(view: self, with: self.slideshow, insets: insets)
        Layout.addSeparator(toBottomOf: self.slideshow)
        let tap = UITapGestureRecognizer(target: self, action: #selector(slideshowWasTapped))
        self.slideshow.addGestureRecognizer(tap)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Actions

    // TODO https://app.asana.com/0/914798787098068/1141894912444857/f
    // TODO need to update pod with this fix
    @objc private func slideshowWasTapped() {
        self.slideshow.presentFullScreenController(from: AppController.shared)
    }

    // MARK: KeyValueUpdateable

    func update(with keyValue: KeyValue) {
        guard let post = keyValue.value.content.post else { return }
        self.update(with: post)
    }

    func update(with post: Post) {
        // TODO https://app.asana.com/0/914798787098068/1139734561448459/f
        // TODO the view needs to be cleared before setting with a single item
        self.slideshow.setImageInputs([])
        self.slideshow.setImageInputs(post.blobInputSources)
    }
}

fileprivate extension Post {

    /// Returns an array of input source wrapping Blob models.
    /// This is artificially limited to 8 for now until we better
    /// understand the performance implications behind fetching
    /// blobs.
    var blobInputSources: [InputSource] {
        let blobs = Array(self.anyBlobs.prefix(8))
        let sources = blobs.map { BlobInputSource($0) }
        return sources
    }
}

private class BlobInputSource: InputSource {

    private let blob: Blob
    private var completionUUID: UUID?

    init(_ blob: Blob) {
        self.blob = blob
    }

    deinit {
        guard let uuid = self.completionUUID else { return }
        Caches.blobs.forgetCompletions(with: uuid, for: self.blob.identifier)
    }

    func load(to imageView: UIImageView,
              with callback: @escaping (UIImage?) -> Void) {
        // set background color first
        imageView.backgroundColor = self.blob.metadata?.averageColor

        // use the cached image first
        if let image = Caches.blobs.cachedImage(for: self.blob.identifier) {
            imageView.image = image
            callback(image)
            return
        }

        // request for image blob
        let uuid = Caches.blobs.imageOrPlaceholder(for: self.blob.identifier) { [weak self] image in
            imageView.fade(to: image, duration: 0.2)
            callback(image)
            self?.completionUUID = nil
        }

        // remember the completion for later
        self.completionUUID = uuid
    }
}
