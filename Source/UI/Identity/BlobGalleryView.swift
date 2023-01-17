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
    var aspectRatio: CGFloat

    @State
    private var selectedBlob: Blob

    @EnvironmentObject
    private var appController: AppController

    init(blobs: [Blob], aspectRatio: CGFloat = 1) {
        self.blobs = blobs
        self.selectedBlob = blobs.first ?? Blob(identifier: .null)
        self.aspectRatio = aspectRatio
    }
    
    var body: some View {
        TabView(selection: $selectedBlob) {
            if blobs.isEmpty {
                Spacer()
            } else {
                ForEach(blobs) { blob in
                    ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
                        .scaledToFill()
                        .tag(blob)
                }
            }
        }
        .onTapGesture {
            appController.open(string: selectedBlob.identifier)
        }
        .tabViewStyle(.page)
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

struct ImageMetadataGalleryView_Previews: PreviewProvider {
    static var sample: Blob {
        Caches.blobs.update(UIImage(named: "test") ?? .remove, for: "&test")
        return Blob(identifier: "&test")
    }
    static var anotherSample: Blob {
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        return Blob(identifier: "&avatar1")
    }
    static var previews: some View {
        Group {
            VStack {
                BlobGalleryView(blobs: [sample])
                BlobGalleryView(blobs: [sample, anotherSample])
            }
            VStack {
                BlobGalleryView(blobs: [sample])
                BlobGalleryView(blobs: [sample, anotherSample])
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(AppController.shared)
    }
}
