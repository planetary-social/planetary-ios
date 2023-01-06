//
//  BlobView.swift
//  Planetary
//
//  Created by Martin Dutra on 13/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit
import Logger

/// Displays a blob with support for a loading indicator if we don't have a it yet and a placeholder image if its not
/// a type we can display (e.g. not an image)
struct BlobView: View {

    @ObservedObject private var blobLoader: BlobLoader

    init(blob: Blob, blobCache: BlobCache = Caches.blobs) {
        self.blobLoader = BlobLoader(blobCache: blobCache, blob: blob)
    }
    
    var body: some View {
        VStack {
            if let data = $blobLoader.data.wrappedValue {
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                } else {
                    Image(uiImage: UIImage.verse.unsupportedBlobPlaceholder)
                        .resizable()
                }
            } else if blobLoader.isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                Localized.Error.unexpected.view
            }
        }
    }
}

/// Publishes a blob's data once it has loaded, with support for cancelling in-flight requests if this
fileprivate class BlobLoader: ObservableObject {

    @Published var data: Data?
    
    @Published var isLoading = true
    
    private var blobCache: BlobCache
    
    init(blobCache: BlobCache, blob: Blob) {
        self.blobCache = blobCache
        Task { await self.load(from: blob) }
    }

    @MainActor private func load(from blob: Blob) async {
        do {
            self.data = try await blobCache.data(for: blob.id)
        } catch {
            Log.optional(error)
        }
        self.isLoading = false
    }
}

struct BlobView_Previews: PreviewProvider {
    
    static var cache: BlobCache = {
        BlobCache(bot: Bots.fake)
    }()
    
    static var sample: Blob {
        cache.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    
    static var loadingSample: Blob {
        Blob(identifier: "&unknown")
    }
    
    static var previews: some View {
        Group {
            BlobView(blob: sample, blobCache: cache)
                .scaledToFit()
            BlobView(blob: loadingSample, blobCache: cache)
                .scaledToFit()
        }
        .padding()
        .background(Color.cardBackground)
    }
}
