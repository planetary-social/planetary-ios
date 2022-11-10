//
//  HashtagSliderView.swift
//  Planetary
//
//  Created by Martin Dutra on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct HashtagSliderView: View {

    var identity: Identity

    @State
    private var hashtags: [Hashtag] = []

    @State
    private var isLoading: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if isLoading || !hashtags.isEmpty {
                HStack {
                    ForEach(hashtags) { hashtag in
                        Button {
                            AppController.shared.open(string: hashtag.string)
                        } label: {
                            SwiftUI.Text(hashtag.string)
                                .foregroundLinearGradient(
                                    LinearGradient(
                                        colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .background(
                            Color.hashtagBg
                                .cornerRadius(99)
                        )
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                .placeholder(when: isLoading) {
                    HStack {
                        Rectangle().fill(
                            Color.hashtagBg
                        )
                        .frame(width: 96, height: 33)
                        .cornerRadius(99)
                        
                        Rectangle().fill(
                            Color.hashtagBg
                        )
                        .frame(width: 96, height: 33)
                        .cornerRadius(99)
                        Rectangle().fill(
                            Color.hashtagBg
                        )
                        .frame(width: 96, height: 33)
                        .cornerRadius(99)
                    }
                    .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                }
            }
        }
        .task {
            isLoading = true
            Task.detached {
                do {
                    let result = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                    await MainActor.run {
                        hashtags = result
                        isLoading = false
                    }
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await MainActor.run {
                        hashtags = []
                        isLoading = false
                    }
                }
            }
        }
    }
}

struct HashtagSliderView_Previews: PreviewProvider {
    static var previews: some View {
        HashtagSliderView(identity: .null)
            .environmentObject(BotRepository.shared)
            .redacted(reason: .placeholder)
            .previewLayout(.sizeThatFits)

        HashtagSliderView(identity: .null)
            .environmentObject(BotRepository.shared)
            .previewLayout(.sizeThatFits)
    }
}
