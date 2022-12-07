//
//  EmptyPostsView.swift
//  Planetary
//
//  Created by Martin Dutra on 29/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct EmptyPostsView: View {
    var body: some View {
        VStack {
            Text("⏳")
                .font(.system(size: 68))
                .padding()
                .padding(.top, 35)
            Text(Localized.Message.noPostsTitle.text)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primaryTxt)
            Text(noPostsDescription)
                .font(.subheadline)
                .foregroundColor(.secondaryTxt)
                .accentColor(.accentTxt)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private let howGossippingWorks = "https://github.com/planetary-social/planetary-ios/wiki/Distributed-Social-Network"

    private var noPostsDescription: AttributedString {
        let unformattedDescription = Localized.Message.noPostsDescription.text(["link": howGossippingWorks])
        do {
            return try AttributedString(
                markdown: unformattedDescription,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            return AttributedString(unformattedDescription)
        }
    }
}
