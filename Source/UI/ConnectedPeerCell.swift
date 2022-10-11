//
//  ConnectedPeerCell.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A cell/row view that displays info about a connected peer.
struct ConnectedPeerCell: View {
    
    var peer: PeerConnectionInfo
    
    var body: some View {
        HStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF264E"), Color(hex: "#8474EA")],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(
                    AvatarImageViewRepresentable(
                        metadata: peer.imageMetadata,
                        animated: true
                    )
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                )
            Text(peer.name ?? peer.id)
                .font(.callout)
                .foregroundColor(Color("mainText"))
                .lineLimit(1)
            Spacer()
        }
        .opacity(peer.isActive ? 1 : 0.4)
        .padding(.horizontal, 14)
        .padding(.vertical, 0)
    }
}

struct ConnectedPeerCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(PeerConnectionInfo.uiPreviewData) { peer in
                ConnectedPeerCell(peer: peer)
            }
        }
    }
}
