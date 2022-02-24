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
    var recentlyDownloadedDuration: String { get }
    var onlinePeersCount: Int { get set }
}

class ConnectedPeersViewCoordinator: ConnectedPeersViewModel {
    
    @Published var peers = [PeerConnectionInfo]()
    
    var recentlyDownloadedPostCount: Int = 0
    
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
    
    private var cancellables = [AnyCancellable]()
    
    private var bot: Bot
        
    init(bot: Bot, statisticsService: BotStatisticsService) {
        self.bot = bot
        Task {
             await statisticsService.subscribe()
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
        }
    }
    
    private func peerConnectionInfo(from peerStatistics: PeerStatistics) async -> [PeerConnectionInfo] {
        var peerConnectionInfo = [PeerConnectionInfo]()
        
        for (ipAddress, identity) in peerStatistics.currentOpen {
            do {
                let about = try await bot.about(identity: "@\(identity).ed25519") // TODO: support other feed formats
                
                peerConnectionInfo.append(
                    PeerConnectionInfo(
                        id: identity,
                        name: about?.name ?? identity,
                        imageID: about?.image?.link,
                        currentlyActive: true
                    )
                )
            } catch {
                peerConnectionInfo.append(
                    PeerConnectionInfo(
                        id: identity,
                        name: nil,
                        imageID: nil,
                        currentlyActive: true
                    )
                )
                Log.optional(error)
                continue
            }
        }
        
        return peerConnectionInfo
    }
}
