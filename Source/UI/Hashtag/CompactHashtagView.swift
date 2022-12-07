//
//  CompactHashtagView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct CompactHashtagView: View {
    var hashtag: Hashtag
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hashtag.string)
                    .font(.headline)
                    .foregroundColor(.primaryTxt)
                Text("\(hashtag.count)")
                    .font(.callout)
                    .foregroundColor(.secondaryTxt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            Image.cellChevron
                .renderingMode(.template)
                .tint(.secondaryTxt)
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
    }
}

struct CompactHashtagView_Previews: PreviewProvider {
    static var previews: some View {
        CompactHashtagView(hashtag: Hashtag(name: "Architecture"))
            .previewLayout(.sizeThatFits)
    }
}
