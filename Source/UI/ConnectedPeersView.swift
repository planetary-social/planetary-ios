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
            // Header
            HStack {
                PeerConnectionAnimationView(peerCount: $viewModel.connectedPeersCount)
                    .padding(.trailing, 2)
                Text.connectedPeers.view
                    .font(.body)
                    .foregroundColor(Color("menuUnselectedItemText"))
                    .lineLimit(1)
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                
                SwiftUI.Text(String(viewModel.connectedPeersCount))
                    .font(.body)
                    .foregroundColor(Color("defaultTint"))
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                Spacer()
            }
            .padding(.top, 11)
            .padding(.bottom, 0)
            .padding(.horizontal, 14)
            
            Color("menuBackgroundColor").frame(height: 1)

            // Peer List
            ScrollView {
                ForEach(viewModel.peers) { peer in
                    ConnectedPeerCell(peer: peer)
                }
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 2) {
                HStack {
                    Text.syncingMessages.view
                        .font(.caption)
                        .foregroundColor(Color("menuUnselectedItemText"))
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
                
                HStack {
                    Text.recentlyDownloaded.view([
                        "postCount": String(viewModel.recentlyDownloadedPostCount),
                        "duration": String(viewModel.recentlyDownloadedPostDuration)
                    ])
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
        .onAppear(perform: viewModel.viewDidAppear)
        .onDisappear(perform: viewModel.viewDidDisappear)
        .background(Color("appBackground"))
        .cornerRadius(10)
        .padding(14)
    }
}

fileprivate class PreviewViewModel: ConnectedPeersViewModel {
    
    var peers = PeerConnectionInfo.uiPreviewData
                
    var recentlyDownloadedPostCount: Int = 62
    var recentlyDownloadedPostDuration: Int = 15
    var connectedPeersCount: Int {
        get {
            peers.filter({ $0.currentlyActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
    func viewDidAppear() {}
    func viewDidDisappear() {}
}

struct ConnectedPeersView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedPeersView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 310))
        
        // iPhone SE Size
        ConnectedPeersView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 175))
            .preferredColorScheme(.dark)
        
        // Accessibility
        ConnectedPeersView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 310))
            .environment(\.sizeCategory, .extraExtraLarge)
    }
}
