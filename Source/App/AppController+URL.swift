//
//  AppController+URL.swift
//  FBTT
//
//  Created by Christoph on 3/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppController {

    func openOSSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func open(url: URL, completion: ((Bool) -> Void)? = nil) {
        Log.info("open(url): \(url.absoluteString)")
        if url.absoluteString.isHashtag { self.pushChannelViewController(for: url.absoluteString) }
        else if let identifier = url.identifier { self.open(identifier: identifier) }
        else { UIApplication.shared.open(url, options: [:], completionHandler: completion) }
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

    // TODO how to extract identifier and content type?
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

    // TODO this is not great because Identity and Identifier
    // as essentially the same so the caller needs to signal intent
    func open(identity: Identity) {
        self.pushViewController(for: .about, with: identity)
    }

    // TODO this is incorrectly scoped, push to the app controller should
    // reset the root controller, not push into a child feature controller
    func pushViewController(for contentType: ContentType,
                            with identifier: Identifier)
    {
        guard contentType == .about else { return }
        let controller = AboutViewController(with: identifier)
        self.push(controller, animated: true)
    }
    

    func pushBlobViewController(for blob: BlobIdentifier) {
        let controller = BlobViewController(with: blob)
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
        let controller = ChannelViewController(named: hashtag)
        self.push(controller)
    }

    // TODO this is incorrectly scoped, push to the app controller should
    // reset the root controller, not push into a child feature controller
    func push(_ controller: UIViewController, animated: Bool = true) {
        guard let featureController = self.mainViewController?.selectedViewController as? UINavigationController else {
            Log.unexpected(.missingValue, "Selected view controller is not a navigation controller")
            return
        }
        featureController.pushViewController(controller, animated: animated)
    }
}
