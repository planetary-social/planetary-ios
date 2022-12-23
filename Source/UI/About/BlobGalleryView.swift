//
//  BlobGalleryView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit
import CryptoKit

struct AVPlayerControllerRepresented : UIViewControllerRepresentable {
    var player : AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        
    }
}

struct BlobGalleryView: View {

    var blobs: [Blob]

    @State
    private var selectedBlob: Blob
    
    @State
    private var enableTapGesture: Bool

    @EnvironmentObject
    private var appController: AppController
    
    @EnvironmentObject
    private var botRepository: BotRepository
    
    private var blobCache: BlobCache

    init(blobs: [Blob], blobCache: BlobCache = Caches.blobs, enableTapGesture: Bool = true) {
        self.blobs = blobs
        self.blobCache = blobCache
        self.selectedBlob = blobs.first ?? Blob(identifier: .null)
        self.enableTapGesture = enableTapGesture
    }
    
    private func canUseAVPlayer(on blob: Blob) -> Bool {
        if blob.identifier == "&uJS2HQ0jE1Mq2QfTn8MwEjIV95YlCspzW++6MTZetCs=.sha256" {
            print("here")
        }
        guard let url = try? botRepository.current.blobFileURL(from: blob.identifier) else {
            return false
        }
        
        let asset = AVURLAsset(url: url)
//        let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4"])
//        return asset.load(.isPlayable)
//        return asset.isPlayable
        
//        let length=Float(asset.duration.value)/Float(asset.duration.timescale)
        return true
//        return length > 0
    }
    
    private func videoPlayer(for url: URL) -> some View {
//        let asset = AVURLAsset(url: url)
        let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4"])
        
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(items: [item])
//        return NoControlsVideoPlayer(player: player)
//        return AVPlayerControllerRepresented(player: player)
        return VideoPlayer(player: player)
    }
    
    var body: some View {
        let tabView = TabView(selection: $selectedBlob) {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    if canUseAVPlayer(on: blob) {
                        if let url = try? botRepository.current.blobFileURL(from: blob.identifier) {
                            VStack {
                                videoPlayer(for: url)
                                Text("video here")
                            }
                        } else {
                            Text("error")
                        }
                    } else {
                        ImageMetadataView(
                            metadata: ImageMetadata(link: blob.identifier),
                            blobCache: blobCache
                        )
                            .scaledToFill()
                            .tag(blob)
                    }
                }
            }
        }
        .tabViewStyle(.page)
        .aspectRatio(1, contentMode: .fit)
        
        if enableTapGesture {
            tabView.onTapGesture {
                appController.open(string: selectedBlob.identifier)
            }
        } else {
            tabView
        }
    }
}

struct ImageMetadataGalleryView_Previews: PreviewProvider {
    
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
    
    static var videoSample: Blob {
        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let data = try! Data(contentsOf: videoURL)
        let blobIdentifier = "&\(SHA256.hash(data: data))=.sha256"
        (Bots.fake as! FakeBot).store(url: videoURL) { _, _ in
            
            
        }
        return Blob(identifier: blobIdentifier)
    }
    
    static var videoPlayer: AVQueuePlayer {
        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let videoPlayer = AVQueuePlayer(items: [item])
//        videoPlayer.actionAtItemEnd = .none
//        videoPlayer.isMuted = true
//        let videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
        return videoPlayer
    }
    
    static var video: some View {
        VideoPlayer(player: videoPlayer)
//        AVPlayerControllerRepresented(player: videoPlayer)
    }
    
    static var previews: some View {
        Group {
            VStack {
                BlobGalleryView(
                    blobs: [
                        videoSample,
                        imageSample,
                        anotherImageSample
                    ],
                    blobCache: cache,
                    enableTapGesture: false
                    
                )
                .background(Color.cardBackground)
            }
            .background(Color.gray)
            .padding()
            .environmentObject(AppController.shared)
            .environmentObject(BotRepository.fake)
            
            video
        }
    }
}
