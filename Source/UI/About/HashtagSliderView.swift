//
//  HashtagSliderView.swift
//  Planetary
//
//  Created by Martin Dutra on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct HashtagSliderView: View {
    @SwiftUI.Environment(\.redactionReasons) private var reasons
    var hashtags: [Hashtag]
    var onHashtagTapHandler: ((Hashtag) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(hashtags) { hashtag in
                    Button {
                        onHashtagTapHandler?(hashtag)
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
                        Color("hashtag-bg")
                            .cornerRadius(99)
                    )
                }
            }
            .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
            .placeholder(when: !reasons.isEmpty) {
                HStack {
                    Rectangle().fill(
                        Color("hashtag-bg")
                    )
                    .frame(width: 96, height: 33)
                    .cornerRadius(99)

                    Rectangle().fill(
                        Color("hashtag-bg")
                    )
                    .frame(width: 96, height: 33)
                    .cornerRadius(99)
                    Rectangle().fill(
                        Color("hashtag-bg")
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
        HashtagSliderView(hashtags: [])
            .redacted(reason: .placeholder)
            .previewLayout(.sizeThatFits)

        HashtagSliderView(hashtags: [Hashtag(name: "Design"), Hashtag(name: "Architecture")])
            .previewLayout(.sizeThatFits)
    }
}
