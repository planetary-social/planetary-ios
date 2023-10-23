//
//  BlobViewController.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import Logger
import CrashReporting

class BlobViewController: ContentViewController {

    private let blob: BlobIdentifier

    private let imageView: UIImageView

    private var completion: UUID?
    
    init(with blob: BlobIdentifier) {
        self.blob = blob
        imageView = UIImageView.forAutoLayout()
        imageView.contentMode = .scaleAspectFit
        super.init(scrollable: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        forgetBlobCompletion()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.contentView, with: self.imageView)
        self.update()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Blob")
        Analytics.shared.trackDidShowScreen(screenName: "blob")
    }

    private func forgetBlobCompletion() {
        guard let uuid = self.completion else { return }
        Caches.blobs.forgetCompletions(with: uuid, for: blob)
    }

    private func update() {
        // always forget any pending completion
        forgetBlobCompletion()

        Task { @MainActor [weak self] in
            guard let blob = self?.blob else {
                return
            }

            // cached image
            if let uiImage = Caches.blobs.image(for: blob) {
                self?.imageView.image = uiImage
                return
            }

            // request image
            let uuid = Caches.blobs.imageOrPlaceholder(for: blob) { [weak self] uiImage in
                self?.imageView.image = uiImage
            }

            self?.completion = uuid
        }
    }
}
