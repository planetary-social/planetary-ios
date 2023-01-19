//
//  EmptyPostsView.swift
//  Planetary
//
//  Created by Martin Dutra on 29/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct EmptyPostsView: View {
    var title: Localizable = Localized.Message.noPostsTitle
    var description: Localizable
    var body: some View {
        VStack {
            Text("⏳")
                .font(.system(size: 68))
                .padding()
                .padding(.top, 35)
            Text(title.text)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primaryTxt)
            Text(noPostsDescription)
                .font(.subheadline)
                .foregroundColor(.secondaryTxt)
                .accentColor(.accent)
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

struct EmptyPostsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                EmptyPostsView(description: Localized.Message.noPostsDescription)
            }
            VStack {
                EmptyPostsView(description: Localized.Message.noPostsDescription)
            }
            .preferredColorScheme(.dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg)
    }
}