//
//  EmptyPostsView.swift
//  Planetary
//
//  Created by Martin Dutra on 29/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct EmptyPostsView: View {
    var description: Localizable
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
        .frame(maxWidth: .infinity)
    }
    
    private let howGossippingWorks = "https://github.com/planetary-social/planetary-ios/wiki/Distributed-Social-Network"

    private var noPostsDescription: AttributedString {
        let unformattedDescription = description.text(["link": howGossippingWorks])
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
