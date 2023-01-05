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

class BlobSource: ObservableObject {
    var blobs: Blobs
    @Published var selected: Blob
    
    init(blobs: Blobs, selected: Blob? = nil) {
        self.blobs = blobs
        self.selected = selected ?? blobs.first ?? Blob(identifier: .null)
    }
}

struct BlobGalleryView: View {

    @ObservedObject
    private var dataSource: BlobSource
    
    var dismissHandler: (() -> Void)?

//    lazy var selectedBlob: Binding<Blob> = {
//    }()
    
    private var fullscreen: Bool {
        dismissHandler != nil
    }

    @EnvironmentObject
    private var appController: AppController
    
    @EnvironmentObject
    private var botRepository: BotRepository
    
    private var blobCache: BlobCache
    
    @State var debugString = "start"
    
    private var blobs: Blobs {
        dataSource.blobs
    }
    
    init(blobSource: BlobSource, blobCache: BlobCache = Caches.blobs, dismissHandler: (() -> Void)? = nil) {
        self.dataSource = blobSource
        self.blobCache = blobCache
        self.dismissHandler = dismissHandler
    }

    init(blobs: [Blob], blobCache: BlobCache = Caches.blobs, dismissHandler: (() -> Void)? = nil) {
        self.init(blobSource: BlobSource(blobs: blobs), blobCache: blobCache, dismissHandler: dismissHandler)
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
        return asset.isPlayable
        
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
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        let tabView = TabView(selection: $dataSource.selected) {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    if fullscreen {
                        BlobFullScreenView(blob: blob, blobCache: blobCache)
                            .offset(y: dragOffset.height)
                            .scaleEffect(1 - min(0.5, abs(dragOffset.height) / 200))
                            .animation(.interactiveSpring(), value: dragOffset)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 40)
                                    .onChanged { gesture in
                                        if gesture.translation.width < 40 {
                                            dragOffset = gesture.translation
                                        }                                     }
                                    .onEnded { _ in
                                        if abs(dragOffset.height) > 100 {
                                            dismissHandler?()
                                            dragOffset = .zero
                                        } else {
                                            dragOffset = .zero
                                        }
                                    }
                            )
                            .tag(blob)
                    } else {
                        BlobThumbnailView(blob: blob, blobCache: blobCache)
                            .tag(blob)
                            .onTapGesture {
                                appController.pushBlobViewController(for: blobs, selected: dataSource.selected)
                            }
                    }
                }
            }
        }
        .tabViewStyle(.page)
        
        if fullscreen {
            tabView
                .background(Color.black.ignoresSafeArea())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    VStack {
                        HStack {
                            Button {
                                dismissHandler?()
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
        } else {
            tabView
                .aspectRatio(1, contentMode: .fit)
        }
                
    }
}

struct BlobThumbnailView: View {
    
        var blob: Blob
    var blobCache: BlobCache
    
    var body: some View {
        ImageMetadataView(
            metadata: ImageMetadata(link: blob.identifier),
            blobCache: blobCache
        )
        .scaledToFill()
    }
}

struct BlobFullScreenView: View {
    
    var blob: Blob
    var blobCache: BlobCache
    
    var body: some View {
        ImageMetadataView(
            metadata: ImageMetadata(link: blob.identifier),
            blobCache: blobCache
        )
        .scaledToFit()
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
            BlobGalleryView(
                blobs: [
                    imageSample,
                    videoSample,
                    anotherImageSample
                ],
                blobCache: cache,
                dismissHandler: nil
            )
            .frame(maxWidth: 400, maxHeight: 400)
            .environmentObject(AppController.shared)
            .environmentObject(BotRepository.fake)
            
            BlobGalleryView(
                blobs: [
                    imageSample,
                    videoSample,
                    anotherImageSample
                ],
                blobCache: cache,
                dismissHandler: {}
            )
            .environmentObject(AppController.shared)
            .environmentObject(BotRepository.fake)
        }
    }
}
