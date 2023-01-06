//
//  BlobThumbnailView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/5/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// Displays a blobs thumbnail scaled to fill the available space.
struct BlobThumbnailView: View {
    
    var blob: Blob
    var blobCache: BlobCache
    
    var body: some View {
        ImageMetadataView(
            blob: blob,
            thumbnail: true,
            blobCache: blobCache
        )
        .scaledToFill()
    }
}

struct BlobThumbnailView_Previews: PreviewProvider {
    
    static var imageSample: Blob {
        cache.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    
    static var cache: BlobCache = {
        BlobCache(bot: Bots.fake)
    }()
    
    static var previews: some View {
        BlobThumbnailView(blob: imageSample, blobCache: cache)
            .frame(width: 300, height: 300)
            .clipped()
    }
}
