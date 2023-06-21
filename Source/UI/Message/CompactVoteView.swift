//
//  CompactVoteView.swift
//  Planetary
//
//  Created by Martin Dutra on 12/2/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct CompactVoteView: View {

    var identifier: MessageIdentifier

    var vote: Vote

    init(identifier: MessageIdentifier, vote: Vote) {
        self.identifier = identifier
        self.vote = vote
    }

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Text(expression)
            .lineLimit(1)
            .font(.body)
            .foregroundColor(.secondaryTxt)
            .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expression: AttributedString {
        var expression: String
        if let explicitExpression = vote.expression,
            explicitExpression.isSingleEmoji {
            expression = explicitExpression
        } else if vote.value > 0 {
            expression = "*\(Localized.likesThis.text)*"
        } else {
            expression = "*\(Localized.dislikesThis.text)*"
        }
        do {
            return try AttributedString(markdown: expression)
        } catch {
            return AttributedString(expression)
        }
    }
}

struct CompactVoteView_Previews: PreviewProvider {
    static var like: Vote {
        Vote(link: .null, value: 1, expression: nil)
    }

    static var previews: some View {
        Group {
            VStack {
                CompactVoteView(identifier: .null, vote: like)
            }
            VStack {
                CompactVoteView(identifier: .null, vote: like)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
