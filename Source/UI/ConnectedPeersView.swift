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
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF264E"), Color(hex: "#8474EA")],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay(
                                SSBImage(
                                    metadata: peer.imageMetadata,
                                    animated: true
                                )
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            )
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
                    SwiftUI.Text("Downloaded \(viewModel.recentlyDownloadedPostCount) in the last " + viewModel.recentlyDownloadedPostDuration)
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
            imageMetadata: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "1",
            name: "Sebastian Heit",
            imageMetadata: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "2",
            name: "Rossina Simonelli",
            imageMetadata: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "3",
            name: "Craig Nicholls",
            imageMetadata: nil,
            currentlyActive: true
        ),
        PeerConnectionInfo(
            id: "4",
            name: "Jordan Wilson",
            imageMetadata: nil,
            currentlyActive: false
        ),
        PeerConnectionInfo(
            id: "5",
            name: "Arun Ramachandaran",
            imageMetadata: nil,
            currentlyActive: false
        ),
    ]
                
    var recentlyDownloadedPostCount: Int = 62
    var recentlyDownloadedPostDuration: String = "15 mins"
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
