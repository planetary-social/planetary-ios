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

    private var isLoading: Bool {
        hashtags == nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if let hashtags = hashtags {
                    ForEach(hashtags) { hashtag in
                        Button {
                            AppController.shared.open(string: hashtag.string)
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
}

struct HashtagSliderView_Previews: PreviewProvider {
    static var previews: some View {
        HashtagSliderView(hashtags: nil)
            .previewLayout(.sizeThatFits)

        HashtagSliderView(hashtags: [Hashtag(name: "Design")])
            .previewLayout(.sizeThatFits)
    }
}
