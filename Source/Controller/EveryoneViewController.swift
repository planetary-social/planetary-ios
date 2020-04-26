//
//  EveryoneViewController.swift
//  Planetary
//
//  Created by Rabble on 4/25/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

import UIKit

class EveryoneViewController: HomeViewController {
    
    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(newPostButtonTouchUpInside))
        return item
    }()

    private lazy var selectPhotoBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-camera")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(selectPhotoButtonTouchUpInside))
        return item
    }()
    
    override init() {
        super.init(scrollable: false, title: .everyone)
        let imageView = UIImageView(image: UIImage(named: "title"))
        imageView.contentMode = .scaleAspectFit
        let view = UIView.forAutoLayout()
        Layout.fill(view: view, with: imageView, respectSafeArea: false)
        self.navigationItem.titleView = view
        self.navigationItem.rightBarButtonItems = [self.newPostBarButtonItem]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func load(animated: Bool = false) {
        Bots.current.refresh() { error, _ in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            Bots.current.everyone() { [weak self] roots, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                self?.refreshControl.endRefreshing()
                self?.removeLoadingAnimation()
                AppController.shared.hideProgress()
             
                if let error = error {
                    self?.alert(error: error)
                } else {
                    self?.update(with: roots, animated: animated)
                }
            }
        }
    }
    


}

