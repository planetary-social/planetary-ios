//
//  BlobGalleryView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct BlobGalleryView: View {

    var blobs: [Blob]

    init(blobs: [Blob]) {
        self.blobs = blobs
        print("Showing blob gallery for:")
        print(blobs.map { "\($0.identifier): \($0.metadata?.mimeType ?? "unknown")" }.joined(separator: "\n"))
    }
    
    var body: some View {
        TabView {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
                        .scaledToFill()
                        .tag(blob.identifier)
                        .onTapGesture {
                            AppController.shared.open(string: blob.identifier)
                        }
                }
            }
        }
        .tabViewStyle(.page)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ImageMetadataGalleryView_Previews: PreviewProvider {
    static var sample: Blob {
        Caches.blobs.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    static var previews: some View {

        BlobGalleryView(blobs: [sample])
            .previewLayout(.sizeThatFits)
    }
}
