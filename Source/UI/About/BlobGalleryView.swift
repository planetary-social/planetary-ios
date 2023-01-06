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

class BlobSource: ObservableObject {
    @Published var blobs: Blobs
    @Published var selected: Blob
    
    init(blobs: Blobs, selected: Blob? = nil) {
        self.blobs = blobs
        self.selected = selected ?? blobs.first ?? Blob(identifier: .null)
    }
}

/// Displays an array of blobs in a gallery.
struct BlobGalleryView: View {

    private var blobCache: BlobCache
    
    private var dismissHandler: (() -> Void)?
    
    @ObservedObject private var dataSource: BlobSource
    
    @EnvironmentObject private var appController: AppController
    
    @EnvironmentObject private var botRepository: BotRepository
    
    @State private var dragOffset: CGSize = .zero
    
    @State private var shareURL: URL?
    
    init(blobSource: BlobSource, blobCache: BlobCache = Caches.blobs, dismissHandler: (() -> Void)? = nil) {
        self.dataSource = blobSource
        self.blobCache = blobCache
        self.dismissHandler = dismissHandler
    }

    init(blobs: [Blob], blobCache: BlobCache = Caches.blobs, dismissHandler: (() -> Void)? = nil) {
        self.init(blobSource: BlobSource(blobs: blobs), blobCache: blobCache, dismissHandler: dismissHandler)
    }
    
    private var blobs: Blobs {
        dataSource.blobs
    }
    
    private var shareButtonDisabled: Binding<Bool> {
        Binding { shareURL == nil } set: { _ in }
    }
    
    private var fullscreen: Bool {
        dismissHandler != nil
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
    
    func fullScreenBlobView(for blob: Blob) -> some View {
        BlobView(blob: blob, blobCache: blobCache)
            .scaledToFit()
        
            // drag to dismiss gesture
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
    }
    
    func thumbnailBlobView(for blob: Blob) -> some View {
        BlobView(blob: blob, blobCache: blobCache)
            .scaledToFill()
            .onTapGesture {
                appController.pushBlobViewController(for: blobs, selected: dataSource.selected)
            }
    }
    
    var tabView: some View {
        TabView(selection: $dataSource.selected) {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    if fullscreen {
                        fullScreenBlobView(for: blob)
                            .tag(blob)
                    } else {
                        thumbnailBlobView(for: blob)
                            .tag(blob)
                    }
                }
            }
        }
        .tabViewStyle(.page)
    }
    
    var body: some View {
        if fullscreen {
            tabView
                .background(Color.black.ignoresSafeArea())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    VStack {
                        HStack {
                            XButton { dismissHandler?() }
                            
                            Spacer()
                            
                            ShareButton(disabled: shareButtonDisabled, action: { showShareSheet() })
                                .task {
                                    await loadShareURL()
                                }
                        }
                        Spacer()
                    }
                )
        } else {
            tabView.aspectRatio(1, contentMode: .fit)
        }
    }
}

struct BlobGalleryView_Previews: PreviewProvider {
    
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
            BlobGalleryView(
                blobs: [imageSample, anotherImageSample],
                blobCache: cache,
                dismissHandler: nil
            )
            .frame(maxWidth: 400, maxHeight: 400)
            .environmentObject(AppController.shared)
            .environmentObject(BotRepository.fake)
            
            BlobGalleryView(
                blobs: [imageSample, anotherImageSample],
                blobCache: cache,
                dismissHandler: {}
            )
            .environmentObject(AppController.shared)
            .environmentObject(BotRepository.fake)
        }
    }
}
