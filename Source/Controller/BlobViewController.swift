//
//  BlobViewController.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BlobViewController: ContentViewController {

    private let blob: BlobIdentifier

    private let imageView: UIImageView = {
        let view = UIImageView.forAutoLayout()
        view.contentMode = .scaleAspectFit
        return view
    }()

    init(with blob: BlobIdentifier) {
        self.blob = blob
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

    private func update() {
        Caches.blobs.image(for: self.blob) {
            [weak self] _, image in
            self?.imageView.image = image
        }
    }
}
