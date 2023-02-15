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

    var hashtags: [Hashtag]?

    @EnvironmentObject
    private var appController: AppController

    private var isLoading: Bool {
        hashtags == nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if let hashtags = hashtags {
                    ForEach(hashtags) { hashtag in
                        Button {
                            appController.open(string: hashtag.string)
                        } label: {
                            Text(hashtag.string)
                                .font(.footnote)
                                .foregroundLinearGradient(.horizontalAccent)
                        }
                        .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .background(Color.hashtagBg.cornerRadius(99))
                    }
                }
            }
            .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
            .placeholder(when: isLoading) {
                HStack {
                    ForEach((1...3).reversed(), id: \.self) { _ in
                        ZStack {
                            Text(verbatim: "#\(String.loremIpsum(words: 1))")
                                .font(.footnote)
                                .hidden()
                        }
                        .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .background(Color.hashtagBg.cornerRadius(99))
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
            }
        }
    }
}

struct HashtagSliderView_Previews: PreviewProvider {
    static var hashtags: [Hashtag] {
        [Hashtag(name: "Design"), Hashtag(name: "Architecture"), Hashtag(name: "Chess")]
    }
    static var previews: some View {
        Group {
            VStack {
                HashtagSliderView(hashtags: nil)
                HashtagSliderView(hashtags: hashtags)
            }
            VStack {
                HashtagSliderView(hashtags: nil)
                HashtagSliderView(hashtags: hashtags)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(AppController.shared)
    }
}
