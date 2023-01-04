//
//  BlobView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/4/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct BlobView: View {
    
    var blob: Blob
    
    var blobCache: BlobCache = Caches.blobs
    
    var dismissHandler: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            ImageMetadataView(
                metadata: ImageMetadata(link: blob.identifier),
                blobCache: blobCache
            )
            .tag(blob)
            .scaledToFit()
            Spacer()
        }
        .overlay(
            VStack {
                HStack {
                    Button {
                        dismissHandler()
                    } label: {
                        let xmark = Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .padding(16)
                            .foregroundColor(Color.black)
                        
                        xmark
//                            .overlay(Color.black.mask(xmark))
                            .background(
                                Circle()
                                    .foregroundColor(Color.white)
                                    .frame(width: 30, height: 30)
                            )
                    }

                    Spacer()
                }
                Spacer()
            }
        )
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct BlobView_Previews: PreviewProvider {
    
    static var cache: BlobCache = {
        BlobCache(bot: Bots.fake)
    }()
    
    static var imageSample: Blob {
        cache.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    
    static var anotherImageSample: Blob {
        cache.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        return Blob(identifier: "&avatar1")
    }
    
    static var previews: some View {
        Group {
            BlobView(blob: imageSample, blobCache: cache, dismissHandler: {})
        }
    }
}
