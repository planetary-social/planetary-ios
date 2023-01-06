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

class BlobGalleryViewController: UIViewController, ObservableObject {
    
    @Published var blobSource: BlobSource
    private var fullScreen: Bool
    
    init(blobs: Blobs, selected: Blob? = nil, fullScreen: Bool) {
        self.fullScreen = fullScreen
        self.blobSource = BlobSource(blobs: blobs, selected: selected)
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(blobID: BlobIdentifier, fullScreen: Bool) {
        self.init(blobs: [Blob(identifier: blobID)], fullScreen: fullScreen)
    }
    
    @available(*, unavailable)
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dismissHandler = fullScreen ? { self.dismiss(animated: true) } : nil
        let galleryView = BlobGalleryView(blobSource: blobSource, dismissHandler: dismissHandler)
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        
        let hostingController = UIHostingController(rootView: galleryView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        Layout.fill(view: view, with: hostingController.view, respectSafeArea: !fullScreen)
        hostingController.didMove(toParent: self)
    }
    
    func update(with post: Post) {
        blobSource.blobs = post.anyBlobs
        blobSource.selected = blobSource.blobs.first ?? Blob(identifier: .null)
    }
}
