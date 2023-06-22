//
//  LoadingCard.swift
//  Planetary
//
//  Created by Martin Dutra on 25/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct LoadingCard: View {

    var style: CardStyle

    var body: some View {
        VStack(spacing: 0) {
            PeerConnectionAnimationView(peerCount: 3, color: UIColor.secondaryTxt)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
        }
        .background(
            LinearGradient.cardGradient
        )
        .cornerRadius(20)
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
    }
}

struct LoadingCard_Previews: PreviewProvider {
    static var previews: some View {
        LoadingCard(style: .compact)
    }
}
