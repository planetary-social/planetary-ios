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

@MainActor class BlobViewController: ContentViewController {

    private let blob: BlobIdentifier

    private let imageView: UIImageView
    
    init(with blob: BlobIdentifier) {
        self.blob = blob
        imageView = UIImageView.forAutoLayout()
        imageView.contentMode = .scaleAspectFit
        super.init(scrollable: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private func update() {
        Task {
            imageView.image = await Caches.blobs.imageOrPlaceholder(for: blob)
        }
    }
}
