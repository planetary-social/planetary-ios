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

protocol ConnectedPeersViewModel: ObservableObject {
    var peers: [PeerConnectionInfo] { get }
    var recentlyDownloadedPostCount: Int { get }
    var recentlyDownloadedPostDuration: Int { get }
    var onlinePeersCount: Int { get set }
}

class ConnectedPeersViewCoordinator: ConnectedPeersViewModel {
    
    @Published var peers = [PeerConnectionInfo]()
    
    @Published var recentlyDownloadedPostCount: Int = 0
    
    @Published var recentlyDownloadedPostDuration: Int = 0
    
    var onlinePeersCount: Int {
        get {
            peers.filter({ $0.currentlyActive }).count
        }
        set {
            // We just need this to use `Binding`
            return
        }
    }
    
    private var cancellables = [AnyCancellable]()
    
    private var bot: Bot
        
    init(bot: Bot, statisticsService: BotStatisticsService) {
        self.bot = bot
        
        Task {
             let statisticsPublisher = await statisticsService.subscribe()
            
            // Wire up peers array to the statisticsService
            statisticsPublisher
                .map { $0.peer }
                .flatMap { peerStatistics in
                    return Future { promise in
                        Task.detached {
                            let connectionInfo = await self.peerConnectionInfo(from: peerStatistics)
                            promise(.success(connectionInfo))
                        }
                    }
                }
                .receive(on: RunLoop.main)
                .sink { [weak self] in
                    self?.peers = $0
                }
                .store(in: &self.cancellables)
            
            // Wire up recentlyDownloadedPostCount and recentlyDownloadedDuration to the statistics 
            statisticsPublisher
                .sink(receiveValue: { statistics in
                    self.recentlyDownloadedPostCount = statistics.recentlyDownloadedPostCount
                    self.recentlyDownloadedPostDuration = statistics.recentlyDownloadedPostDuration
                })
                .store(in: &cancellables)
        }
    }
    
    private func peerConnectionInfo(from peerStatistics: PeerStatistics) async -> [PeerConnectionInfo] {
        var peerConnectionInfo = [PeerConnectionInfo]()
        
        for (_, publicKey) in peerStatistics.currentOpen {
            do {
                // TODO: support other feed formats
                let identity = "@\(publicKey).ed25519"
                if let about = try await bot.about(identity: identity)  {
                    peerConnectionInfo.append(
                        PeerConnectionInfo(
                            id: publicKey,
                            name: about.name ?? identity,
                            imageMetadata: about.image,
                            currentlyActive: true
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
                    name: publicKey,
                    imageMetadata: nil,
                    currentlyActive: true
                )
            )
        }
        
        return peerConnectionInfo
    }
}
