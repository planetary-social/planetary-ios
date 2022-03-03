//
//  ConnectedPeersCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Combine
import Logger

protocol ConnectedPeerListViewModel: ObservableObject {
    var peers: [PeerConnectionInfo] { get }
    var recentlyDownloadedPostCount: Int { get }
    var recentlyDownloadedPostDuration: Int { get }
    var connectedPeersCount: Int { get set }
    func peerTapped(_: PeerConnectionInfo)
    func viewDidAppear()
    func viewDidDisappear()
}

protocol ConnectedPeerListRouter: AlertRouter {
    func showProfile(for identity: Identity)
}

enum ConnectedPeerListError: LocalizedError {
    case identityNotFound
    
    var errorDescription: String? {
        switch (self) {
        case .identityNotFound:
            return Text.identityNotFound.text
        }
    }
}

class ConnectedPeerListCoordinator: ConnectedPeerListViewModel {
    
    @Published var peers = [PeerConnectionInfo]()
    
    @Published var recentlyDownloadedPostCount: Int = 0
    
    @Published var recentlyDownloadedPostDuration: Int = 0
    
    var connectedPeersCount: Int {
        get {
            peers.filter({ $0.isActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
    
    var router: ConnectedPeerListRouter
    
    private var statisticsService: BotStatisticsService
    
    private var cancellables = [AnyCancellable]()
        
    private var bot: Bot
        
    init(bot: Bot, statisticsService: BotStatisticsService, router: ConnectedPeerListRouter) {
        self.bot = bot
        self.statisticsService = statisticsService
        self.router = router
    }
    
    
    func peerTapped(_ connectionInfo: PeerConnectionInfo) {
        guard let identity = connectionInfo.identity else {
            router.alert(error: ConnectedPeerListError.identityNotFound)
            return
        }
        
        router.showProfile(for: identity)
    }
    
    func viewDidAppear() {
        Task {
            await subscribeToBotStatistics()
        }
    }
    
    func viewDidDisappear() {
        unsubscribeFromBotStatistics()
    }
        
    private func subscribeToBotStatistics() async {
        let statisticsPublisher = await statisticsService.subscribe()
        
        // Wire up peers array to the statisticsService
        statisticsPublisher
            .map { $0.peer }
            .asyncFlatMap { peerStatistics in
                await self.peerConnectionInfo(from: peerStatistics)
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.peers = $0
            }
            .store(in: &self.cancellables)
        
        // Wire up recentlyDownloadedPostCount and recentlyDownloadedDuration to the statistics
        statisticsPublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { statistics in
                self.recentlyDownloadedPostCount = statistics.recentlyDownloadedPostCount
                self.recentlyDownloadedPostDuration = statistics.recentlyDownloadedPostDuration
            })
            .store(in: &cancellables)
        
    }
    
    private func unsubscribeFromBotStatistics() {
        cancellables.forEach { $0.cancel() }
    }
    
    /// This function cross references the raw `PeerStatistics` data with `About` messages in the `ViewDatabase` to
    /// produce `[PeerConnectionInfo]`.
    ///
    /// Note: This function will only discover `About` messages for ed25519 feeds right now. Adding support for
    /// other feed formats is tracked in https://github.com/planetary-social/planetary-ios/issues/400
    private func peerConnectionInfo(from peerStatistics: PeerStatistics) async -> [PeerConnectionInfo] {
        // Map old peers in as inactive
        var peerConnectionInfo = peers.map { (oldPeer: PeerConnectionInfo) -> PeerConnectionInfo in
            var newPeer = oldPeer
            newPeer.isActive = false
            return newPeer
        }
        
        // Walk through peer statistics and create new connection info
        for (_, publicKey) in peerStatistics.currentOpen {
            peerConnectionInfo.removeAll(where: { $0.id == publicKey })
            do {
                let identity = "@\(publicKey).ed25519"
                if let about = try await bot.about(identity: identity)  {
                    peerConnectionInfo.append(
                        PeerConnectionInfo(
                            id: publicKey,
                            identity: identity,
                            name: about.name ?? publicKey,
                            imageMetadata: about.image,
                            isActive: true
                        )
                    )
                    continue
                }
            } catch {
                Log.optional(error)
            }
            
            peerConnectionInfo.append(
                PeerConnectionInfo(
                    id: publicKey,
                    identity: nil,
                    name: publicKey,
                    imageMetadata: nil,
                    isActive: true
                )
            )
        }
        
        return peerConnectionInfo.sorted { lhs, rhs in
            guard lhs.isActive == rhs.isActive else {
                return lhs.isActive ? true : false
            }
            
            return lhs.name ?? "" < rhs.name ?? ""
        }
    }
}
