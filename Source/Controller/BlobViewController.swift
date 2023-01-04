//
//  BlobViewController.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class BlobViewController: UIViewController {

    private let blob: Blob

    convenience init(for blobID: BlobIdentifier) {
        self.init(for: Blob(identifier: blobID))
    }
    
    init(for blob: Blob) {
        self.blob = blob
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let blobView = BlobView(blob: blob) { self.dismiss(animated: true) }
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        
        let hostingController = UIHostingController(rootView: blobView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
