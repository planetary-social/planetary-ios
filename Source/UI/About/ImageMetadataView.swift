//
//  ImageMetadataView.swift
//  Planetary
//
//  Created by Martin Dutra on 13/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit

struct ImageMetadataView: View {

    var blob: Blob
    var thumbnail: Bool

    @ObservedObject private var imageLoader: ImageLoader
    
    @State private var blobSymlink: URL?
    
    private var blobCache: BlobCache

    init(blob: Blob, thumbnail: Bool, blobCache: BlobCache = Caches.blobs) {
        self.blob = blob
        self.thumbnail = thumbnail
        self.blobCache = blobCache
        self.imageLoader = ImageLoader(blobCache: blobCache)
    }
    
    @State private var avPlayer: AVPlayer?
    @State var audioPlayer: AVAudioPlayer?
    
    private func updateVideoPlayer(with url: URL) {
//        let mimeType = "video/mp4; codecs=\"avc1.42E01E, mp4a.40.2\""
//        let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])

//        let asset = AVAsset(url: url)
//        let playerItem = AVPlayerItem(asset: asset)
//        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer = AVPlayer(url: url)
//        return VideoPlayer(player: player)
//        return AVPlayerControllerRepresented(player: player)
    }
    
    private var videoPlayer: some View {
        Group {
            if let url = blobSymlink, let avPlayer {
                VideoPlayer(player: avPlayer)
            } else {
                Text("error") // TODO
            }
        }
        .task {
            blobSymlink = await blobCache.symbolicLink(for: blob, fileExtension: "mp4")
            if let blobSymlink {
                updateVideoPlayer(with: blobSymlink)
            }
        }
    }
    
    var body: some View {
        VStack {
            if let data = $imageLoader.data.wrappedValue {
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                } else {
                    Image(uiImage: UIImage.verse.unsupportedBlobPlaceholder)
                        .resizable()
                }
            } else if imageLoader.isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                Image("missing-about-icon")
                    .resizable()
            }
        }.task(id: blob.id) {
            await imageLoader.load(from: blob)
        }
    }
}

fileprivate class ImageLoader: ObservableObject {

    @Published
    var data: Data?
    
    @Published
    var isLoading = true

    var blob: Blob?
    private var completion: UUID?
    
    private var blobCache: BlobCache
    
    init(blobCache: BlobCache) {
        self.blobCache = blobCache
    }

    deinit {
        self.forgetBlobCompletion()
    }

    private func forgetBlobCompletion() {
        guard let identifier = self.blob?.identifier else { return }
        guard let uuid = self.completion else { return }
        blobCache.forgetCompletions(with: uuid, for: identifier)
    }

    @MainActor
    func load(from blob: Blob) async {
        self.isLoading = true
        
        // always forget any pending completion
        forgetBlobCompletion()
        self.blob = blob
        
        do {
            self.data = try await blobCache.data(for: blob.id)
        } catch {
            print(error) // TODO
        }
        self.isLoading = false

//        await MainActor.run { [weak self] in
//
//            // cached image
//            if let uiImage = blobCache.image(for: blob.identifier) {
//                self?.image = uiImage
//                self?.isLoading = false
//                return
//            }
//
//            // request image
//            let uuid = blobCache.imageOrPlaceholder(for: blob.identifier) { [weak self] uiImage in
//                self?.image = uiImage
//            }
//
//            self?.metadata = metadata
//            self?.completion = uuid
//        }
    }
}

struct ImageMetadataView_Previews: PreviewProvider {
    
    static var cache: BlobCache = {
        BlobCache(bot: Bots.fake)
    }()
    
    static var sample: Blob {
        cache.update(UIImage(named: "test") ?? .remove, for: "&test")
        let data = UIImage(named: "test")!.pngData()!
        Bots.fake.store(data: data, for: "&test") { _, _ in }
        return Blob(identifier: "&test")
    }
    
    static var loadingSample: Blob {
        Blob(identifier: "&unknown")
    }
    
    static var videoSample: Blob {
        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let data = try! Data(contentsOf: videoURL)
        let blobIdentifier = "&\(data.sha256)=.sha256"
        Bots.fake.store(url: videoURL) { _, _ in }
        return Blob(identifier: blobIdentifier, name: "video:home.mp4")
    }
    
    static var previews: some View {
        Group {
            ImageMetadataView(blob: sample, thumbnail: true, blobCache: cache)
                .scaledToFit()
            ImageMetadataView(blob: videoSample, thumbnail: true, blobCache: cache)
                .scaledToFit()
            ImageMetadataView(blob: loadingSample, thumbnail: true, blobCache: cache)
                .scaledToFit()
        }
        .padding()
        .background(Color.cardBackground)
    }
}
