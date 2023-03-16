//
//  LoadingView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
    var text: String?

    var body: some View {
        ZStack {
            if let text = text {
                VStack(spacing: 15) {
                    animationView
                    Text(text)
                        .foregroundColor(.secondaryTxt)
                }
                .padding()
                .background(LinearGradient.cardGradient)
                .cornerRadius(20)
            } else {
                animationView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var animationView: some View {
        PeerConnectionAnimationView(peerCount: 3, color: UIColor.secondaryTxt)
            .scaleEffect(1.3)
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LoadingView()
            LoadingView(text: "Loading")
        }
        VStack {
            LoadingView()
            LoadingView(text: "Loading")
        }
        .preferredColorScheme(.dark)
    }
}
