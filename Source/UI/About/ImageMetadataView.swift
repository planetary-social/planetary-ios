//
//  ImageMetadataView.swift
//  Planetary
//
//  Created by Martin Dutra on 13/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct ImageMetadataView: View {

    var metadata: ImageMetadata?

    @ObservedObject private var imageLoader: ImageLoader
    
    private var blobCache: BlobCache

    init(metadata: ImageMetadata?, blobCache: BlobCache = Caches.blobs) {
        self.metadata = metadata
        self.blobCache = blobCache
        self.imageLoader = ImageLoader(blobCache: blobCache)
    }
    
    var body: some View {
        VStack {
            Group {
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                } else if imageLoader.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                } else {
                    Image("missing-about-icon")
                        .resizable()
                }
            }
        }.task(id: metadata) {
            await loadImage(from: metadata)
        }
    }

    private func loadImage(from metadata: ImageMetadata?) async {
        await imageLoader.load(from: metadata)
    }
}

fileprivate class ImageLoader: ObservableObject {

    @Published
    var image: UIImage?
    
    @Published
    var isLoading = true

    var metadata: ImageMetadata?
    private var completion: UUID?
    
    private var blobCache: BlobCache
    
    init(blobCache: BlobCache) {
        self.blobCache = blobCache
    }

    deinit {
        self.forgetBlobCompletion()
    }

    private func forgetBlobCompletion() {
        guard let identifier = self.metadata?.identifier else { return }
        guard let uuid = self.completion else { return }
        blobCache.forgetCompletions(with: uuid, for: identifier)
    }

    func load(from metadata: ImageMetadata?) async {
        // always forget any pending completion
        forgetBlobCompletion()

        await MainActor.run { [weak self] in
            guard let metadata = metadata, metadata.link != .null else {
                isLoading = false
                return
            }

            // cached image
            if let uiImage = blobCache.image(for: metadata.identifier) {
                self?.image = uiImage
                self?.isLoading = false
                return
            }

            // request image
            let uuid = blobCache.imageOrPlaceholder(for: metadata.identifier) { [weak self] uiImage in
                self?.image = uiImage
            }

            self?.metadata = metadata
            self?.completion = uuid
        }
    }
}

struct ImageMetadataView_Previews: PreviewProvider {
    static var sample: ImageMetadata {
        Caches.blobs.update(UIImage(named: "test") ?? .remove, for: "&test")
        return ImageMetadata(link: "&test")
    }
    static var loadingSample: ImageMetadata {
        ImageMetadata(link: "&unknown")
    }
    static var previews: some View {
        Group {
            ImageMetadataView(metadata: sample)
            ImageMetadataView(metadata: loadingSample)
        }
        .padding()
        .background(Color.cardBackground)
    }
}
