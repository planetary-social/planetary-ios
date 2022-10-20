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
    @StateObject private var imageLoader = ImageLoader()

    init(metadata: ImageMetadata?) {
        self.metadata = metadata
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image("missing-about-icon")
                    .resizable()
            }
        }.task(id: metadata) {
            await loadImage(from: metadata)
        }
    }

    private func loadImage(from metadata: ImageMetadata?) async {
        await imageLoader.load(from: metadata)
    }
}

struct ImageMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        ImageMetadataView(metadata: ImageMetadata(link: "&avatar1"))
            .previewLayout(.sizeThatFits)
    }
}

fileprivate class ImageLoader: ObservableObject {

    @Published var image: UIImage?

    var metadata: ImageMetadata?
    private var completion: UUID?

    deinit {
        self.forgetBlobCompletion()
    }

    private func forgetBlobCompletion() {
        guard let identifier = self.metadata?.identifier else { return }
        guard let uuid = self.completion else { return }
        Caches.blobs.forgetCompletions(with: uuid, for: identifier)
    }

    func load(from metadata: ImageMetadata?) async {
        // always forget any pending completion
        forgetBlobCompletion()

        await MainActor.run { [weak self] in
            guard let metadata = metadata, metadata.link != .null else {
                return
            }

            // cached image
            if let uiImage = Caches.blobs.image(for: metadata.identifier) {
                self?.image = uiImage
                return
            }

            // request image
            let uuid = Caches.blobs.imageOrPlaceholder(for: metadata.identifier) { [weak self] uiImage in
                self?.image = uiImage
            }

            self?.metadata = metadata
            self?.completion = uuid
        }
    }
}
