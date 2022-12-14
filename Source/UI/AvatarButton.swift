//
//  ProfileButton.swift
//  FBTT
//
//  Created by Christoph on 6/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AvatarButton: ImageButton {

    var didUpdateAboutObserver: NSObjectProtocol?
    
    convenience init() {
        self.init(type: .custom)
        self.useAutoLayout()
        self.contentMode = .scaleAspectFill
        self.imageView?.contentMode = .scaleAspectFill
        self.setImage(UIImage.verse.missingAbout, for: .normal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.round()
    }
    
    deinit {
        removeObservers()
    }

    func setImageForMe() {
        Task {
            setImage(for: try? await Bots.current.about())
        }
    }

    func setImage(for about: About?) {
        let updateBlock = { [weak self] (notification: Notification) in
            guard let newAbout = notification.about, let about = about, newAbout.identity == about.identity else {
                return
            }
            self?.setImage(for: newAbout)
        }
        self.removeObservers()
        self.didUpdateAboutObserver = NotificationCenter.default.addObserver(
            forName: .didUpdateAbout,
            object: nil,
            queue: .main,
            using: updateBlock
        )
        self.reset()
        guard let image = about?.image else { return }
        self.set(image: image)
    }

    func reset() {
        self.setImage(UIImage.verse.missingAbout, for: .normal)
    }
    
    private func removeObservers() {
        if let observer = self.didUpdateAboutObserver {
            NotificationCenter.default.removeObserver(observer)
            self.didUpdateAboutObserver = nil
        }
    }
}
