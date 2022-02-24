//
//  ConnectedPeersView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/22/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct ConnectedPeersView<ViewModel>: View where ViewModel: ConnectedPeersViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            HStack {
                PeerConnectionAnimationView(peerCount: $viewModel.onlinePeersCount)
                SwiftUI.Text("Online Peers")
                    .font(.body)
                    .foregroundColor(Color("menuUnselectedItemText"))
                
                SwiftUI.Text(String(viewModel.onlinePeersCount))
                    .font(.body)
                    .foregroundColor(Color("defaultTint"))

                Spacer()
            }
            .padding(.top, 11)
            .padding(.bottom, 0)
            .padding(.horizontal, 14)
            
            Color.white.frame(height: 1)

            ScrollView {
                ForEach(viewModel.peers) { peer in
                    HStack {
                        Circle()
                            .frame(width: 26, height: 26)
                            .foregroundColor(Color("menuUnselectedItemText"))
                        SwiftUI.Text(peer.name ?? peer.id)
                            .font(.callout)
                            .foregroundColor(Color("menuUnselectedItemText"))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 0)
                }
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                HStack {
                    SwiftUI.Text("Syncing Messages...")
                        .font(.caption)
                        .foregroundColor(Color("menuUnselectedItemText"))
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
                
                HStack {
                    SwiftUI.Text("Downloaded \(viewModel.recentlyDownloadedPostCount) in the last " + viewModel.recentlyDownloadedDuration)
                        .font(.caption)
                        .foregroundColor(Color("secondaryText"))
                        .scaledToFit()
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
            }
            .frame(minHeight: 32)
            .padding(.horizontal, 15)
            .padding(.bottom, 14)
            .padding(.top, 1)
        }
        .background(Color("appBackground"))
        .cornerRadius(10)
        .padding(14)
    }
}

fileprivate class PreviewViewModel: ConnectedPeersViewModel {
    
    var peers = [
        PeerConnectionInfo(
            id: "0",
            name: "Amanda Bee 🐝",
            imageID: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "1",
            name: "Sebastian Heit",
            imageID: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "2",
            name: "Rossina Simonelli",
            imageID: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "3",
            name: "Craig Nicholls",
            imageID: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "4",
            name: "Jordan Wilson",
            imageID: nil,
            currentlyActive: false
        ),
        PeerConnectionInfo(
            id: "5",
            name: "Arun Ramachandaran",
            imageID: nil,
            currentlyActive: false
        ),
    ]
                
    var recentlyDownloadedPostCount: Int = 62
    var recentlyDownloadedDuration: String = "15 mins"
    var onlinePeersCount: Int {
        get {
            peers.filter({ $0.currentlyActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
}

struct ConnectedPeersView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedPeersView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 310))
        
        // iPhone SE Size
        ConnectedPeersView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 175))
    }
}
