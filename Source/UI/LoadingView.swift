//
//  LoadingView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            PeerConnectionAnimationView(peerCount: 3, color: UIColor.secondaryTxt)
                .scaleEffect(1.3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
