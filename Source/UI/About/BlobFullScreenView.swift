//
//  BlobFullScreenView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/5/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// Displays a blob scaled to fit the available space.
struct BlobFullScreenView: View {
    
    var blob: Blob
    var blobCache: BlobCache
    
    var body: some View {
        ImageMetadataView(
            blob: blob,
            thumbnail: false,
            blobCache: blobCache
        )
        .scaledToFit()
    }
}

struct BlobFullScreenView_Previews: PreviewProvider {
    
    static var imageSample: Blob {
        cache.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    
    static var videoSample: Blob {
        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let data = try! Data(contentsOf: videoURL)
        let blobIdentifier = "&\(data.sha256)=.sha256"
        (Bots.fake as! FakeBot).store(url: videoURL) { _, _ in }
        return Blob(identifier: blobIdentifier, name: "video:video.mp4")
    }
    
    static var cache: BlobCache = {
        BlobCache(bot: Bots.fake)
    }()
    
    static var previews: some View {
        BlobFullScreenView(blob: imageSample, blobCache: cache)
        BlobFullScreenView(blob: videoSample, blobCache: cache)
    }
}
