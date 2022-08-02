//
//  HelpDrawerView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit
import Logger

/// A view that displays some help text. Intended to be presented in a sheet or popover.
struct HelpDrawerView: View {
    
    private let tabName: String
    private let tabImageName: String
    private let heroImageName: String?
    private let helpTitle: String
    private let bodyText: String
    private let highlightedWord: String?
    private let highlight: LinearGradient
    private let link: URL?
    private let inDrawer: Bool
    private let tipIndex: Int
    private let nextTipAction: (() -> Void)?
    private let previousTipAction: (() -> Void)?
    private let dismissAction: () -> Void
    
    private let videoPlayer: AVQueuePlayer
    private let videoLooper: AVPlayerLooper
    private let videoAspectRatio: CGFloat
    
    /// This hard coded URL is temporary. See comment on `imageOrVideo` property
    // swiftlint:disable force_unwrapping
    let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
    // swiftlint:enable force_unwrapping
    
    init(
        tabName: String,
        tabImageName: String,
        heroImageName: String?,
        helpTitle: String,
        bodyText: String,
        highlightedWord: String?,
        highlight: LinearGradient,
        link: URL?,
        inDrawer: Bool,
        tipIndex: Int,
        nextTipAction: (() -> Void)?,
        previousTipAction: (() -> Void)?,
        dismissAction: @escaping () -> Void
    ) {
        self.tabName = tabName
        self.tabImageName = tabImageName
        self.heroImageName = heroImageName
        self.helpTitle = helpTitle
        self.bodyText = bodyText
        self.highlightedWord = highlightedWord
        self.highlight = highlight
        self.link = link
        self.inDrawer = inDrawer
        self.tipIndex = tipIndex
        self.nextTipAction = nextTipAction
        self.previousTipAction = previousTipAction
        self.dismissAction = dismissAction
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        videoPlayer = AVQueuePlayer(playerItem: item)
        videoPlayer.isMuted = true
        videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
        
        let videoSize = asset.tracks.first?.naturalSize
        self.videoAspectRatio = (videoSize?.height ?? 1) / (videoSize?.width ?? 1)
    }
    
    /// This is the image or video that will be displayed at the top of the screen.
    /// It's only half implemented. Original design had videos at the top of each drawer but
    /// only one video was ready so the rest get static images for now.
    var imageOrVideo: some View {
        VStack(spacing: 0) {
            if let heroImageName = heroImageName {
                Image(heroImageName)
                    .resizable()
                    .scaledToFit()
            } else {
                SingleAxisGeometryReader(axis: .horizontal) { containerWidth in
                    NoControlsVideoPlayer(player: videoPlayer)
                        .frame(width: containerWidth, height: videoAspectRatio * containerWidth)
                        .onAppear { videoPlayer.play() }
                }
            }
            Spacer()
        }
        .cornerRadius(cornerRadius, corners: [.topLeft, .topRight])
        .clipped()
    }
    
    private let borderWidth: CGFloat = 6
    private let cornerRadius: CGFloat = 8
    
    var body: some View {
        ZStack {
            
            // Gradient border
            LinearGradient.diagonalAccent
            
            // Background color
            Color("menuBorderColor")
                .cornerRadius(cornerRadius, corners: inDrawer ? [.topLeft, .topRight] : [.allCorners])
                .padding(.top, borderWidth)
                .padding(.horizontal, borderWidth)
                .padding(.bottom, inDrawer ? 0 : borderWidth)
            
            // Content
            VStack {
                ZStack {
                    
                    // Image / video is stacked at the top behind the text content.
                    imageOrVideo
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Text Container
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                
                                // Tab name and icon
                                FancySectionTitle(
                                    gradient: LinearGradient.diagonalAccent,
                                    image: Image(tabImageName),
                                    text: tabName
                                )
                                
                                // Title
                                SwiftUI.Text(helpTitle)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(Color("mainText"))
                                    .font(.title.weight(.medium))
                                
                                // Body text
                                HighlightedText(
                                    bodyText,
                                    highlightedWord: highlightedWord,
                                    highlight: highlight,
                                    link: link
                                )
                            }
                            .padding(.top, 15)
                            .padding(.horizontal, 25)
                            .padding(.bottom, 25)
                        }
                        .background(Color("menuBorderColor").padding(.horizontal, -100))
                        .fixedSize(horizontal: false, vertical: true)
                        
                        // Tip navigation section
                        HStack {
                            Button {
                                previousTipAction?()
                            } label: {
                                Image(systemName: "arrow.backward")
                                    .foregroundColor(Color("mainText"))
                            }
                            .disabled(previousTipAction == nil)
                            .opacity(previousTipAction == nil ? 0.3 : 1.0)
                            
                            Spacer()
                            SwiftUI.Text(
                                Text.Help.indexOfTip.text(
                                    [
                                        "tipIndex": String(tipIndex),
                                        "totalTipCount": "5"
                                    ]
                                )
                            )
                            .font(.footnote)
                            Spacer()
                            
                            Button {
                                nextTipAction?()
                            } label: {
                                Image(systemName: "arrow.forward")
                                    .foregroundColor(Color("mainText"))
                            }
                            .disabled(nextTipAction == nil)
                            .opacity(nextTipAction == nil ? 0.3 : 1.0)
                            .cornerRadius(cornerRadius)
                        }
                        .padding(.bottom, 25)
                        .padding(.horizontal, 25)
                        .background(Color("menuBorderColor"))
                    }
                    .clipped()
                    
                    // X button
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                dismissAction()
                            } label: {
                                let icon = Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(16)
                                
                                icon
                                    .overlay(LinearGradient.horizontalAccent.mask(icon))
                                    .background(
                                        Circle()
                                            .foregroundColor(Color.white)
                                            .frame(width: 30, height: 30)
                                    )
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.top, borderWidth)
            .padding(.horizontal, borderWidth)
            .padding(.bottom, inDrawer ? 0 : borderWidth)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct HomeHelpView_Previews: PreviewProvider {
    
    static var iPadPreview: some View {
        let view = HelpDrawerView(
            tabName: Text.home.text,
            tabImageName: "tab-icon-home",
            heroImageName: nil,
            helpTitle: Text.Help.Home.title.text,
            bodyText: Text.Help.Home.body.text,
            highlightedWord: Text.Help.Home.highlightedWord.text,
            highlight: .diagonalAccent,
            link: nil,
            inDrawer: false,
            tipIndex: 1,
            nextTipAction: {},
            previousTipAction: {},
            dismissAction: {}
        )
        return view
            .previewLayout(.fixed(width: 320, height: 493))
            .preferredColorScheme(.light)
    }
    
    static var homeTabPreview: some View {
        HelpDrawerView(
            tabName: Text.home.text,
            tabImageName: "tab-icon-home",
            heroImageName: nil,
            helpTitle: Text.Help.Home.title.text,
            bodyText: Text.Help.Home.body.text,
            highlightedWord: Text.Help.Home.highlightedWord.text,
            highlight: .diagonalAccent,
            link: URL(string: "https://planetary.social"),
            inDrawer: true,
            tipIndex: 1,
            nextTipAction: {},
            previousTipAction: {},
            dismissAction: {}
        )
    }
    
    static var notificationsTabPreview: some View {
        HelpDrawerView(
            tabName: Text.notifications.text,
            tabImageName: "tab-icon-notifications",
            heroImageName: "help-hero-notifications",
            helpTitle: Text.Help.Notifications.title.text,
            bodyText: Text.Help.Notifications.body.text,
            highlightedWord: nil,
            highlight: .diagonalAccent,
            link: nil,
            inDrawer: true,
            tipIndex: 3,
            nextTipAction: {},
            previousTipAction: {},
            dismissAction: {}
        )
    }
    
    static var previews: some View {
        homeTabPreview
            .previewLayout(.fixed(width: 375, height: 493))
            .preferredColorScheme(.dark)
        
        // iPhone 13 Pro Max
        homeTabPreview
            .previewLayout(.fixed(width: 428, height: 502))
            .preferredColorScheme(.dark)
        
        // iPhone SE 2nd gen
        homeTabPreview
            .previewLayout(.fixed(width: 375, height: 351))
            .preferredColorScheme(.dark)
        
        notificationsTabPreview
            .previewLayout(.fixed(width: 375, height: 493))
            .preferredColorScheme(.light)
        
        notificationsTabPreview
            .previewLayout(.fixed(width: 375, height: 493))
            .preferredColorScheme(.dark)
            .environment(\.sizeCategory, .extraExtraLarge)
        
        // iPad popover size
        iPadPreview
    }
}
