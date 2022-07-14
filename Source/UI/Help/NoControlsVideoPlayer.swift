//
//  NoControlsVideoPlayer.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit

struct NoControlsVideoPlayer2: UIViewRepresentable {

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
//        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
//        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
}

/// A SwiftUI video player that doesn't show onscreen controls.
/// Adapted from https://stackoverflow.com/a/71874787/982195
struct NoControlsVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
//        view.playerLayer.contentsGravity = .resizeAspect
        view.playerLayer.needsDisplayOnBoundsChange = true
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: AVPlayerLayerView, context: Context) {
//        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
//        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
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
//        if frame.size != playerLayer.videoRect.size {
//            let newSize = playerLayer.videoRect.size
//            frame = CGRect(
//                origin: CGPoint.zero,
//                size: newSize
//            )
//            layer.frame = CGRect(
//                origin: CGPoint.zero,
//                size: newSize
//            )
//        }
        print("video size: \(playerLayer.videoRect)")
        print("preferred video size: \(playerLayer.preferredFrameSize())")
//        frame = CGRect(origin: CGPoint.zero, size: CGSize(width: frame.width, height: playerLayer.videoRect.height))
//        playerLayer.frame.origin = CGPoint.zero
//        frame.height = playerLayer.videoRect.height
//        frame = playerLayer.bounds
        playerLayer.frame = bounds
    }
//    override var intrinsicContentSize: CGSize {
//        playerLayer.videoRect.size
//    }
}

class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.play()

        playerLayer.player = player
        playerLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        

//        VStack {
            NoControlsVideoPlayer2()
                .onAppear {
                    videoPlayer.play()
                }
//                .edgesIgnoringSafeArea(.all)
//                .scaledToFill()
                .scaledToFit()
                .background(Color.blue)
//        }
//        .background(Color.green)
//        .previewLayout(.sizeThatFits)
    }
}
