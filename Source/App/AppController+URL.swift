//
//  AppController+URL.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import SwiftUI

extension AppController {

    func openOSSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func open(url: URL, completion: ((Bool) -> Void)? = nil) {
        Log.info("open(url): \(url.absoluteString)")
        if url.absoluteString.isHashtag {
            self.pushChannelViewController(for: url.absoluteString)
        } else if let identifier = url.identifier {
            self.open(identifier: identifier)
        } else if Star.isValid(invite: url.absoluteString) {
            self.redeem(invite: url.absoluteString)
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    }
    
    func open(string: String) {
        Log.info("open(string): \(string)")
        switch string.prefix(1) {
        case "&":
            self.pushBlobViewController(for: string)
        case "%":
            self.pushThreadViewController(for: string)
        case "@":
            self.pushViewController(for: .about, with: string)
        case "#":
            self.pushChannelViewController(for: string)
        default:
            return
        }
    }

    func open(identifier: Identifier) {
        switch identifier.sigil {
        case .blob:
            self.pushBlobViewController(for: identifier)
        case .message:
            self.pushThreadViewController(for: identifier)
        case .feed:
            self.pushViewController(for: .about, with: identifier)
        case .unsupported:
            return
        }
    }

    // this is not great because Identity and Identifier
    // as essentially the same so the caller needs to signal intent
    func open(identity: Identity) {
        self.pushViewController(for: .about, with: identity)
    }
    
    func redeem(invite: String) {
        guard let featureController = self.mainViewController?.selectedViewController as? UINavigationController else {
            Log.unexpected(.missingValue, "Selected view controller is not a navigation controller")
            return
        }
        let controller = UIAlertController(
            title: "This is an invite to a Pub",
            message: "Are you sure you want to redeem this invite?",
            preferredStyle: .alert
        )
        var action = UIAlertAction(title: Localized.cancel.text, style: .cancel) { _ in
            controller.dismiss(animated: true, completion: nil)
        }
        controller.addAction(action)

        action = UIAlertAction(title: Localized.yes.text, style: .default) { [weak self] _ in
            controller.dismiss(animated: false, completion: nil)
            self?.showProgress()
            let star = Star(invite: invite)
            let operation = RedeemInviteOperation(star: star, shouldFollow: true)
            operation.completionBlock = { [weak self] in
                switch operation.result {
                case .success:
                    DispatchQueue.main.async {
                        self?.hideProgress()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.hideProgress()
                        self?.alert(error: error)
                    }
                case .none:
                    DispatchQueue.main.async {
                        self?.hideProgress()
                    }
                }
            }
            self?.addOperation(operation)
        }
        controller.addAction(action)
        featureController.present(alertController: controller, animated: true)
    }

    // this is incorrectly scoped, push to the app controller should
    // reset the root controller, not push into a child feature controller
    func pushViewController(for contentType: ContentType, with identity: Identity) {
        guard contentType == .about else { return }
        let view = IdentityView(identity: identity)
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        let controller = UIHostingController(rootView: view)
        self.push(controller, animated: true)
    }

    func pushBlobViewController(for blob: BlobIdentifier) {
        let view = BlobGalleryView(blobs: [Blob(identifier: blob)], enableTapGesture: false)
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        let controller = UIHostingController(rootView: view)
//        let controller = BlobViewController(with: blob)
        self.push(controller)
    }
    
    func pushThreadViewController(for identifier: MessageIdentifier) {
        Bots.current.thread(rootKey: identifier) { (root, _, error) in
            if let root = root {
                let controller = ThreadViewController(with: root)
                self.push(controller)
            } else if let error = error {
                self.alert(error: error)
            }
        }
    }

    func pushChannelViewController(for hashtag: String) {
        let view = HashtagView(hashtag: Hashtag.named(hashtag))
            .environmentObject(BotRepository.shared)
            .environmentObject(AppController.shared)
        self.push(UIHostingController(rootView: view))
    }

    // this is incorrectly scoped, push to the app controller should
    // reset the root controller, not push into a child feature controller
    func push(_ controller: UIViewController, animated: Bool = true) {
        guard let featureController = self.mainViewController?.selectedViewController as? UINavigationController else {
            Log.unexpected(.missingValue, "Selected view controller is not a navigation controller")
            return
        }
        featureController.dismiss(animated: true)
        featureController.pushViewController(controller, animated: animated)
    }
}
