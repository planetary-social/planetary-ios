//
//  NoControlsVideoPlayer.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit

/// A SwiftUI video player that doesn't show onscreen controls.
/// Adapted from https://stackoverflow.com/a/71874787/982195
struct NoControlsVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.needsDisplayOnBoundsChange = true
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: AVPlayerLayerView, context: Context) {
    }
}

// swiftlint:disable force_cast

/// A simple `UIView` wrapper around `AVPlayerLayer`.
class AVPlayerLayerView: UIView {

    // Override the property to make AVPlayerLayer the view's backing layer.
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    // The associated player object.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping

struct NoControlsVideoPlayer_Previews: PreviewProvider {
    
    static let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
    
    /// Must keep a strong reference to the looper
    static var videoLooper: AVPlayerLooper!
    static var videoPlayer: AVQueuePlayer = createVideoPlayer()
    
    static func createVideoPlayer() -> AVQueuePlayer {
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let videoPlayer = AVQueuePlayer(playerItem: item)
        videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
        return videoPlayer
    }
    
    static var previews: some View {
        VStack {
            NoControlsVideoPlayer(player: videoPlayer)
                .onAppear {
                    videoPlayer.play()
                }
                .background(Color.blue)
        }
        .background(Color.green)
        .previewLayout(.sizeThatFits)
    }
}
