//
//  AvatarImageView.swift
//  FBTT
//
//  Created by Christoph on 8/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Secrets

class AvatarImageView: ImageView {
    
    @MainActor override var image: UIImage? {
        get {
            super.image
        }
        set {
            super.image = newValue ?? UIImage.verse.missingAbout
            self.contentMode = .scaleAspectFill
        }
    }
    
    var borderColor: UIColor?
    var borderWidth: CGFloat?

    convenience init(borderColor: UIColor? = nil, borderWidth: CGFloat? = nil) {
        self.init(image: UIImage.verse.missingAbout)
        self.contentMode = .scaleAspectFill
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let color = borderColor, let width = borderWidth, !sk.isSkeletonActive {
            round(borderColor: color, borderWidth: width)
        } else {
            round()
        }
    }

    // This is totally "just get it done" code.  Ideally there would be an
    // app-wide service to get remote and cache remote images.  Likely this
    // will need to be part of the incoming cache mechanism.
    @discardableResult
    func load(for person: Person, animate: Bool = false) -> URLSessionDataTask? {
        
        // TODO: This convert 
        if person.image_url == nil, let imageIdentifier = person.image {
            
            // cached image
            if let image = Caches.blobs.image(for: imageIdentifier) {
                 DispatchQueue.main.async {
                    if animate {
                        self.fade(to: image)
                    } else {
                        self.image = image
                    }
                 }
                // return(nil)
            }

            // request image
            Caches.blobs.image(for: imageIdentifier) { [weak self] result in
                
                let image = try? result.get().1
                
                DispatchQueue.main.async {
                    if animate {
                        self?.fade(to: image)
                    } else {
                        self?.image = image
                    }
                }
                return
            }
        }
        
        guard let path = person.image_url, let url = URL(string: path) else { return nil }
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 3)
        
        if let token = Keys.shared.get(key: .blob) {
            request.add(["planetary-blob-authorize": token])
        }
        
        Log.info("url: \(url)")

        let task = URLSession.shared.dataTask(with: request) {
            data, response, _ in
            guard response?.httpStatusCodeError == nil else { return }
            guard let data = data else { return }
            guard let image = UIImage(data: data) else {
                Log.unexpected(.incorrectValue, "Invalid image data for \(path)")
                return
            }

            DispatchQueue.main.async {
                if animate {
                    self.fade(to: image)
                } else {
                    self.image = image
                }
            }
        }
        task.resume()
        return task
    }
}
