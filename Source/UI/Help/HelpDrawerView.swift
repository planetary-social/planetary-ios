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
                NoControlsVideoPlayer(player: videoPlayer)
                    .frame(height: 217)
                    .onAppear {
                        videoPlayer.play()
                    }
            }
        }
        .background(Color(hex: "4a386d"))
    }
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {
                    VStack {
                        ScrollView {
                            VStack(spacing: 0) {
                                imageOrVideo
                                VStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        
                                        // Tab name and icon
                                        FancySectionName(
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
                                }
                                .padding(25)
                            }
                            .edgesIgnoringSafeArea(.all)
                        }
                        .padding(-3)
                        
                        Spacer()
                        
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
                        }
                        .padding(.bottom, 25)
                        .padding(.horizontal, 25)
                        .padding(.top, 10)
                    }
                    .padding(.top, 3)
                    .padding(.horizontal, 3)
                    .background(Color("menuBorderColor"))
                    
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
            .cornerRadius(8, corners: inDrawer ? [.topLeft, .topRight] : [.allCorners])
            .padding(.top, 6)
            .padding(.horizontal, 6)
            .padding(.bottom, inDrawer ? 0 : 6)
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(LinearGradient.diagonalAccent)
    }
}

extension SwiftUI.Text {
    public func foregroundLinearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> some View {
        self.foregroundLinearGradient(
            LinearGradient(
                colors: colors,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
    
    public func foregroundLinearGradient(_ gradient: LinearGradient) -> some View {
        self.overlay {
            gradient.mask(
                self
            )
        }
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
    
    static var defaultPreview: some View {
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
    
    static var previews: some View {
        defaultPreview
            .previewLayout(.fixed(width: 320, height: 493))
            .preferredColorScheme(.dark)
        
        defaultPreview
            .previewLayout(.fixed(width: 320, height: 493))
            .preferredColorScheme(.light)
        
        defaultPreview
            .previewLayout(.fixed(width: 320, height: 493))
            .preferredColorScheme(.dark)
            .environment(\.sizeCategory, .extraExtraLarge)
        
        // iPad popover size
        iPadPreview
    }
}

struct FancySectionName: View {
    
    var gradient: LinearGradient
    var image: Image
    var text: String
    
    var body: some View {
        HStack(spacing: 6) {
            gradient
                .mask(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: .infinity)
                .fixedSize(horizontal: true, vertical: false)
            SwiftUI.Text(text)
                .font(.subheadline.smallCaps())
                .foregroundLinearGradient(gradient)
                .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension String {
    func indices(of occurrence: String) -> [Int] {
        var indices = [Int]()
        var position = startIndex
        while let range = range(of: occurrence, range: position..<endIndex) {
            let i = distance(from: startIndex,
                             to: range.lowerBound)
            indices.append(i)
            let offset = occurrence.distance(from: occurrence.startIndex,
                                             to: occurrence.endIndex) - 1
            guard let after = index(range.lowerBound,
                                    offsetBy: offset,
                                    limitedBy: endIndex) else {
                                        break
            }
            position = index(after: after)
        }
        return indices
    }
}

extension String {
    func ranges(of searchString: String) -> [Range<String.Index>] {
        let _indices = indices(of: searchString)
        let count = searchString.count
        return _indices.map({ index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: $0+count) })
    }
}
