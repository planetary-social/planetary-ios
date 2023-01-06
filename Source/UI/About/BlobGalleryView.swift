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
import Logger

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
    @Published var blobs: Blobs
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
    
    @State private var shareURL: URL?
    
    private var shareButtonDisabled: Bool {
        shareURL == nil
    }
    
    func loadShareURL() async {
        let blob = dataSource.selected
        async let data = blobCache.data(for: blob.id)
        var filename = blob.name?.trimmed ?? ""
        if filename.isEmpty {
            
            filename = String(blob.identifier.hexEncodedString().prefix(8))
            
        }
        if filename.starts(with: "video:") {
            filename = String(filename.dropFirst("video:".count))
        }
        if filename.starts(with: "audio:") {
            filename = String(filename.dropFirst("audio:".count))
        }
        
        var activityURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(filename)")
        
        // try to determine file extension if there isn't one
        if activityURL.pathExtension.isEmpty {
            do {
                let blobType = Blob.type(for: try await data)
                switch blobType {
                case .unsupported:
                    break
                case .jpg, .png, .pdf, .vnd, .gif, .txt, .tiff:
                    activityURL = activityURL.appendingPathExtension(blobType.rawValue)
                }
            } catch {
                Log.optional(error)
            }
        }
        
        shareURL = activityURL
    }
    
    func showShareSheet() {
        let blob = dataSource.selected
        Task {
            let data = try? await self.blobCache.data(for: blob.id)
            if let shareURL, let data {
                try data.write(to: shareURL)
                
                let top = appController.topViewController
                let activityViewController = UIActivityViewController(
                    activityItems: [shareURL],
                    applicationActivities: nil
                )
                activityViewController.popoverPresentationController?.sourceView = top.view
                top.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
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
                                        }
                                    }
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
                        Button {
                            appController.pushBlobViewController(for: blobs, selected: dataSource.selected)
                        } label: {
                            BlobThumbnailView(blob: blob, blobCache: blobCache)
                        }
                        .tag(blob)
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
                                let xmark = Image(systemName: "xmark")
                                    .font(.system(size: 25))
                                    .padding(16)
                                    .foregroundColor(Color.white)
                                
                                xmark
                            }
                            
                            Spacer()
                            
                            Button {
                                showShareSheet()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 25))
                                    .padding(16)
                                    .foregroundColor(shareButtonDisabled ? Color.gray : Color.white)
                            }
                            .disabled(shareButtonDisabled)
                            .task {
                                await loadShareURL()
                            }
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

//class BlobActivityProvider: UIActivityItemProvider {
//
//    var blob: Blob
//    var blobCache: BlobCache
//    var activityURL: URL?
//
//    init(blob: Blob, cache: BlobCache) {
//        self.blob = blob
//        self.blobCache = cache
//
//        var filename = blob.name?.trimmed ?? ""
//        if filename.isEmpty {
//
//            filename = String(blob.identifier.hexEncodedString().prefix(8))
//
//        }
//        if filename.starts(with: "video:") {
//            filename = String(filename.dropFirst("video:".count))
//        }
//        if filename.starts(with: "audio:") {
//            filename = String(filename.dropFirst("audio:".count))
//        }
//
//        activityURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(filename)")
//
//        super.init(placeholderItem: activityURL)
//    }
//
//    private var blobData: Data?
//
//    override var item: Any {
//        if let data = Self.synchronouslyGetData(for: blob, from: blobCache), var activityURL = activityURL {
//
//        } else {
//            return NSObject()
//        }
//    }
//
//    private static func synchronouslyGetData(for blob: Blob, from cache: BlobCache) -> Data? {
//        var data: Data?
//        let lock = NSLock()
//        lock.lock()
//        DispatchQueue(label: "BlobActivityProvider").sync {
//            cache.data(for: blob.id) { result in
//                data = try? result.get().1
//                lock.unlock()
//            }
//        }
//        lock.lock()
//        lock.unlock()
//        return data
//    }
//}

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
        (Bots.fake as! FakeBot).store(url: videoURL) { _, _ in }
        return Blob(identifier: blobIdentifier, name: "video:vide.mp4")
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
