//
//  ConnectedPeersView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/22/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A view that shows currently connected scuttlebutt peers and metadata about the connections.
struct ConnectedPeerListView<ViewModel>: View where ViewModel: ConnectedPeerListViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            
            // Header
            HStack {
                
                // Animation
                PeerConnectionAnimationView(peerCount: viewModel.connectedPeersCount ?? 1)
                    .padding(.trailing, 2)
                Text.connectedPeers.view
                    .font(.body)
                    .foregroundColor(Color("menuUnselectedItemText"))
                    .lineLimit(1)
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                // Online Peers count
                let count = viewModel.connectedPeersCount.map { String($0) } ?? "~"
                SwiftUI.Text(count)
                    .font(.body)
                    .foregroundColor(Color("defaultTint"))
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                    .animation(.default)
            }
            .padding(.top, 11)
            .padding(.bottom, 0)
            .padding(.horizontal, 14)
            
            Color("menuBackgroundColor").frame(height: 1)

            // Peer List
            ScrollView {
                ForEach(viewModel.peers ?? []) { peer in
                    Button {
                        viewModel.peerTapped(peer)
                    } label: {
                        ConnectedPeerCell(peer: peer)
                    }
                    .animation(.spring())
                    .transition(.move(edge: .top))
                }
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 2) {
                
                if let postCount = viewModel.recentlyDownloadedPostCount,
                   let duration = viewModel.recentlyDownloadedPostDuration {

                    HStack {
                        Text.syncingMessages.view
                            .font(.caption)
                            .foregroundColor(Color("mainText"))
                            .minimumScaleFactor(0.5)
                        Spacer()
                    }
                    
                    
                    
                    HStack {
                        Text.recentlyDownloaded.view([
                            "postCount": String(postCount),
                            "duration": String(duration)
                        ])
                            .font(.caption)
                            .foregroundColor(Color("secondaryText"))
                            .scaledToFit()
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                    }
                } else {
                    // Loading message
                    HStack {
                        Text.loading.view
                            .font(.caption)
                            .foregroundColor(Color("mainText"))
                            .minimumScaleFactor(0.5)
                        Spacer()
                    }
                }
            }
            .frame(minHeight: 32)
            .padding(.horizontal, 15)
            .padding(.bottom, 14)
            .padding(.top, 1)
        }
        .onAppear(perform: viewModel.viewDidAppear)
        .onDisappear(perform: viewModel.viewDidDisappear)
        .background(Color("menuBorderColor"))
        .cornerRadius(10, corners: [.topLeft, .topRight, .bottomRight])
        .cornerRadius(20, corners: [.bottomLeft])
        .padding(14)
    }
}

fileprivate class PreviewViewModel: ConnectedPeerListViewModel {
    
    static var emptyModel: PreviewViewModel {
        let vm = PreviewViewModel()
        vm.peers = nil
        vm.recentlyDownloadedPostCount = nil
        vm.recentlyDownloadedPostDuration = nil
        return vm
    }
    
    var peers: [PeerConnectionInfo]? = PeerConnectionInfo.uiPreviewData
                
    var recentlyDownloadedPostCount: Int? = 62
    var recentlyDownloadedPostDuration: Int? = 15
    var connectedPeersCount: Int? {
        get {
            peers?.filter({ $0.isActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
    func peerTapped(_: PeerConnectionInfo) {}
    func viewDidAppear() {}
    func viewDidDisappear() {}
}

struct ConnectedPeersView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedPeerListView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 310))
            .background(Color("menuBackgroundColor"))
        
        // iPhone SE Size
        ConnectedPeerListView(viewModel: PreviewViewModel())
            .background(Color("menuBackgroundColor"))
            .previewLayout(.fixed(width: 254, height: 175))
            .preferredColorScheme(.dark)
        
        // Accessibility
        ConnectedPeerListView(viewModel: PreviewViewModel())
            .previewLayout(.fixed(width: 254, height: 310))
            .environment(\.sizeCategory, .extraExtraLarge)
        
        // Empty
        ConnectedPeerListView(viewModel: PreviewViewModel.emptyModel)
            .previewLayout(.fixed(width: 254, height: 310))
    }
}
