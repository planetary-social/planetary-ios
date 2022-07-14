//
//  HomeHelpView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import AVKit


struct HomeHelpView: View {
    
    static let videoURL = Bundle.main.url(forResource: "HomeFeedHelp", withExtension: "mp4")!
    
    let dismissAction: () -> Void
    
    var body: some View {
        HelpDrawer(
            tabName: Text.home.text,
            tabImageName: "tab-icon-home",
            helpTitle: Text.Help.Home.title.text,
            bodyText: Text.Help.Home.body.text,
            highlightedWord: Text.Help.Home.highlightedWord.text,
            dismissAction: dismissAction
        )
    }
}
struct HelpDrawer: View {
    
    //    private let videoPlayer: AVQueuePlayer
    //    private let videoLooper: AVPlayerLooper
    
    private let tabName: String
    private let tabImageName: String
    private let helpTitle: String
    private let bodyText: String
    private let highlightedWord: String
    private let dismissAction: () -> Void
    
    init(
        tabName: String,
        tabImageName: String,
        helpTitle: String,
        bodyText: String,
        highlightedWord: String,
        dismissAction: @escaping () -> Void
    ) {
        self.tabName = tabName
        self.tabImageName = tabImageName
        self.helpTitle = helpTitle
        self.bodyText = bodyText
        self.highlightedWord = highlightedWord
        self.dismissAction = dismissAction
        //        let asset = AVAsset(url: videoURL)
        //        let item = AVPlayerItem(asset: asset)
        //        videoPlayer = AVQueuePlayer(playerItem: item)
        //        videoPlayer.isMuted = true
        //        videoLooper = AVPlayerLooper(player: videoPlayer, templateItem: item)
    }
    
    private let horizontalGradient = LinearGradient(
        colors: [ Color(hex: "#F08508"), Color(hex: "#F43F75")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    private let diagonalGradient = LinearGradient(
        colors: [ Color(hex: "#F08508"), Color(hex: "#F43F75")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            
            // Orange border
//            Rectangle()
//                .fill(diagonalGradient)
//                .cornerRadius(15, corners: [.topLeft, .topRight])
            
            VStack {
                ZStack {
                    VStack  {
                        ScrollView {
                            VStack {
                                // Video, disabled for now.
                                //                                NoControlsVideoPlayer(player: videoPlayer)
                                //                                    .frame(height: 237)
                                //                                    .onAppear {
                                //                                        videoPlayer.play()
                                //                                    }
                                VStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        
                                        // Tab name and icon
                                        FancySectionName(
                                            gradient: diagonalGradient,
                                            image: Image(tabImageName),
                                            text: tabName
                                        )
                                        
                                        // Title
                                        SwiftUI.Text(helpTitle)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(Color("mainText"))
                                            .font(.title.weight(.medium))
                                        
                                        // Body text
                                        GradientHighlightedText(
                                            bodyText,
                                            highlightedWord: highlightedWord,
                                            highlight: diagonalGradient
                                        )
                                    }
                                    
                                }
                                .padding(25)
                            }
                        }
                        
                        Spacer()
                        
                        // Tip navigation section
                        HStack {
//                            Button {
//
//                            } label: {
//                                Image(systemName: "arrow.backward")
//                                    .foregroundColor(Color("mainText"))
//
//                            }

                            Spacer()
                            SwiftUI.Text("1 of 5 tips")
                                .font(.footnote)
                            Spacer()

//                            Button {
//
//                            } label: {
//                                Image(systemName: "arrow.forward")
//                                    .foregroundColor(Color("mainText"))
//                            }
                        }
                        .padding(25)
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
                                    .overlay(horizontalGradient.mask(icon))
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
            //            .cornerRadius(15, corners: [.topLeft, .topRight])
            .padding(.top, 6)
            .padding(.horizontal, 6)
        }
        .background(Color("menuBorderColor"))
        .edgesIgnoringSafeArea(.bottom)
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
    static var previews: some View {
        HomeHelpView(dismissAction: {})
            .previewLayout(.sizeThatFits)
//            .previewDevice("iPhone 13 Pro")
            .preferredColorScheme(.dark)
        
        HomeHelpView(dismissAction: {})
            .previewDevice("iPhone 13 Pro")
            .preferredColorScheme(.light)
        
        HomeHelpView(dismissAction: {})
            .previewDevice("iPhone 13 Pro")
            .preferredColorScheme(.dark)
            .environment(\.sizeCategory, .extraExtraLarge)
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

struct GradientHighlightedText: View {
    
    let text: String
    let highlightedWord: String
    let highlightGradient: LinearGradient
    
    /// An array of segments of text, along with a bool specifying if they should be highlighted.
    private var segments: [(text: String, highlight: Bool)]
    
    init(_ text: String, highlightedWord: String, highlight: LinearGradient) {
        self.text = text
        self.highlightedWord = highlightedWord
        self.highlightGradient = highlight
        
        if let rangeOfHighlightedWord = text.ranges(of: highlightedWord).first {
            segments = []
            let beforeHighlightedWord = text[..<rangeOfHighlightedWord.lowerBound]
            if !beforeHighlightedWord.isEmpty {
                segments.append((text: String(beforeHighlightedWord), highlight: false))
            }
            
            segments.append((text: highlightedWord, highlight: true))
            
            let afterHighlightedWord = text[rangeOfHighlightedWord.upperBound...]
            if !afterHighlightedWord.isEmpty {
                segments.append((text: String(afterHighlightedWord), highlight: false))
            }
        } else {
            segments = [(text: text, highlight: false)]
        }
    }
    
    var bodyText: SwiftUI.Text {
        var bodyText = SwiftUI.Text("")
        for segment in segments {
            bodyText = bodyText + SwiftUI.Text(segment.text)
                .foregroundColor(segment.highlight ? .clear : Color("secondaryText"))
        }
        return bodyText
    }
    
    var highlightedText: SwiftUI.Text {
        var highlightedText = SwiftUI.Text("")
        for segment in segments {
            highlightedText = highlightedText + SwiftUI.Text(segment.text)
                .foregroundColor(segment.highlight ? .black : .clear)
        }
        return highlightedText
    }
    
    var body: some View {
        // layer the text blocks so that the gradient shows through.
        // Note: gradient here is too wide. Need to restrict it to just the word "Discover"
        ZStack {
            // Build two Text objects with the same dimensions. One for the body text where the highlighted word is
            // transparent, and one that only has the highlighted word.
            bodyText
            highlightedText
                .foregroundLinearGradient(highlightGradient)
        }
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
