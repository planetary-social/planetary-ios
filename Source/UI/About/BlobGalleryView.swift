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
        controller.showsPlaybackControls = true
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
    
    @State var debugString = "start"

    init(blobs: [Blob], blobCache: BlobCache = Caches.blobs, enableTapGesture: Bool = true) {
        self.blobs = blobs
        self.blobCache = blobCache
        self.selectedBlob = blobs.first ?? Blob(identifier: .null)
        self.enableTapGesture = enableTapGesture
    }
    
    private func createSymbolicLink(for blob: Blob) -> URL? {
        guard let blobURL = try? botRepository.current.blobFileURL(from: blob.identifier) else {
            return nil
        }
//        let blobURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        debugString = blobURL.absoluteString
        let linkURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(UUID().uuidString).mp4")
        try! FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: blobURL)
//        return Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        return linkURL
    }
    
    private func canUseAVPlayer(on blob: Blob) -> Bool {
        debugString = "here"
        if blob.identifier == "&uJS2HQ0jE1Mq2QfTn8MwEjIV95YlCspzW++6MTZetCs=.sha256" {
            print("here")
        }
            
        guard let url = createSymbolicLink(for: blob) else {
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
        let asset = AVURLAsset(url: url)
//        let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "video/mp4; codecs=\"avc1.42E01E, mp4a.40.2\""])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        return AVPlayerControllerRepresented(player: player)
//        return VideoPlayer(player: player)
    }
    
    private var hash: some View {
        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let data = try! Data(contentsOf: videoURL)
        let blobIdentifier = "&\(data.sha256)=.sha256"
        return Text(blobIdentifier)
    }
    
    var body: some View {
        let tabView = TabView(selection: $selectedBlob) {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    if canUseAVPlayer(on: blob) {
                        if let url = createSymbolicLink(for: blob) {
                            VStack {
                                videoPlayer(for: url)
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
        
        VStack {
            Text(debugString)
            if enableTapGesture {
                tabView.onTapGesture {
                    appController.open(string: selectedBlob.identifier)
                }
            } else {
                tabView
            }
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
        let blobIdentifier = "&\(data.sha256)=.sha256"
        (Bots.fake as! FakeBot).store(url: videoURL) { _, _ in
            
            
        }
        return Blob(identifier: blobIdentifier)
    }
    
    static var videoPlayer: AVPlayer {
        let blobURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let linkURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())/\(UUID().uuidString).mp4")
        try! FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: blobURL)
//        let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
        let videoURL = linkURL
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
//        let videoPlayer = AVQueuePlayer(items: [item])
        let videoPlayer = AVPlayer(playerItem: item)
//        videoPlayer.actionAtItemEnd = .none
//        videoPlayer.isMuted = true
//        let videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
//        return AVPlayerControllerRepresented(player: AVPlayer(playerItem: item))
        return videoPlayer
    }
    
    static var video: some View {
//        VideoPlayer(player: videoPlayer)
        AVPlayerControllerRepresented(player: videoPlayer)
    }
    
    static var previews: some View {
        Group {
            VStack {
                BlobGalleryView(
                    blobs: [
                        videoSample,
//                        imageSample,
//                        anotherImageSample
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
