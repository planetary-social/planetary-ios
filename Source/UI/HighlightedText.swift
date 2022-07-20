//
//  HighlightedText.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Logger

struct HighlightedText: View {
    
    let text: String
    let highlightedWord: String?
    let highlightGradient: LinearGradient
    let link: URL?
    
    enum Segment {
        case body(String)
        case highlighted(String)
        case space
    }
    
    /// An array of segments of text, along with a bool specifying if they should be highlighted.
    private var segments: [Segment]
    
    init(_ text: String, highlightedWord: String?, highlight: LinearGradient, link: URL?) {
        self.text = text
        self.highlightedWord = highlightedWord
        self.highlightGradient = highlight
        self.link = link
        
        if let highlightedWord = highlightedWord,
            let rangeOfHighlightedWord = text.ranges(of: highlightedWord).first {
            segments = []
            let beforeHighlightedWord = String(text[..<rangeOfHighlightedWord.lowerBound])
            if !beforeHighlightedWord.isEmpty {
                segments.append(.body(beforeHighlightedWord))
                
                // Add spaces back because markdown parsing strips them
                if beforeHighlightedWord.suffix(1) == " " {
                    segments.append(.space)
                }
            }
            
            segments.append(.highlighted(highlightedWord))
            
            let afterHighlightedWord = String(text[rangeOfHighlightedWord.upperBound...])
            if !afterHighlightedWord.isEmpty {
                
                // Add spaces back because markdown parsing strips them
                if afterHighlightedWord.prefix(1) == " " {
                    segments.append(.space)
                }
                segments.append(.body(String(afterHighlightedWord)))
            }
        } else {
            segments = [.body(text)]
        }
    }
    
    var bodyText: SwiftUI.Text {
        buildTextFromSegments(
            segments: segments,
            highlightBuilder: { string in
                textView(markdown: string).foregroundColor(.clear)
            },
            bodyBuilder: { string in
                textView(markdown: string).foregroundColor(Color("secondaryText"))
            }
        )
    }
    
    var highlightedText: SwiftUI.Text {
        buildTextFromSegments(
            segments: segments,
            highlightBuilder: { string in
                textView(markdown: string).foregroundColor(.black)
            },
            bodyBuilder: { string in
                textView(markdown: string).foregroundColor(.clear)
            }
        )
    }
    
    var linkText: some View {
        let linkText = buildTextFromSegments(
            segments: segments,
            highlightBuilder: { string in
                var view: SwiftUI.Text
                if let link = link {
                    let linkMarkdown = "[\(string)](\(link.absoluteURL))"
                    view = textView(markdown: linkMarkdown)
                } else {
                    view = textView(markdown: string)
                }
                return view
            },
            bodyBuilder: { string in
                textView(markdown: string).foregroundColor(.clear)
            }
        )

        return linkText.tint(.clear)
    }
    
    private func textView(markdown: String) -> SwiftUI.Text {
        var attributedString: AttributedString
        do {
            attributedString = try AttributedString(markdown: markdown)
        } catch {
            Log.optional(error)
            attributedString = AttributedString(markdown)
        }
        return SwiftUI.Text(attributedString)
    }
    
//    private func append(markdown string: String, to textView: SwiftUI.Text) -> Text {
//        var attributedString: AttributedString
//        do {
//            attributedString = try AttributedString(markdown: string)
//        } catch {
//            Log.optional(error)
//            attributedString = AttributedString(string)
//        }
//
//        let spacer: SwiftUI.Text
//        if textView.content
//
//        return textView + spacer + SwiftUI.Text(attributedString)
//    }
    
    private func buildTextFromSegments(segments: [Segment], highlightBuilder: (String) -> SwiftUI.Text, bodyBuilder: (String) -> SwiftUI.Text) -> SwiftUI.Text {
        var textView = SwiftUI.Text("")
        for segment in segments {
            // swiftlint:disable shorthand_operator
            switch segment {
            case .body(let string):
                textView = textView + bodyBuilder(string)
            case .highlighted(let string):
                textView = textView + highlightBuilder(string)
            case .space:
                textView = textView + SwiftUI.Text(" ")
            }
            // swiftlint:enable shorthand_operator
        }
        return textView
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
            linkText
        }
    }
}

// swiftlint:disable force_unwrapping
struct HighlightedText_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HighlightedText(
                Text.Help.Discover.body.text,
                highlightedWord: Text.Help.Discover.highlightedWord.text,
                highlight: .diagonalAccent,
                link: URL(string: "https://planetary.social")!
            )
            .padding()
        }
        .background(Color("menuBorderColor"))
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
