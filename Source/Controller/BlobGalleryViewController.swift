//
//  BlobGalleryViewController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/4/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class BlobGalleryViewController: UIViewController {
    
    private var blobSource = BlobSource(blobs: [])
    
    init(blobs: Blobs, selected: Blob? = nil) {
        super.init(nibName: nil, bundle: nil)
        blobSource = BlobSource(blobs: blobs, selected: selected)
    }
    
    convenience init(blobID: BlobIdentifier) {
        self.init(blobs: [Blob(identifier: blobID)])
    }
    
    @available(*, unavailable)
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let galleryView = BlobGalleryView(blobSource: blobSource, dismissHandler: { self.dismiss(animated: true) })
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        
        let hostingController = UIHostingController(rootView: galleryView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        Layout.fill(view: view, with: hostingController.view, respectSafeArea: false)
        hostingController.didMove(toParent: self)
    }
    
    func update(with post: Post) {
        blobSource.blobs = post.anyBlobs
    }
}
