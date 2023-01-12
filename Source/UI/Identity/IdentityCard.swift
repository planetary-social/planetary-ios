//
//  IdentityCard.swift
//  Planetary
//
//  Created by Martin Dutra on 12/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct IdentityCard: View {
    var identityOrAbout: Either<Identity, About>
    var style = CardStyle.compact

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var about: About?

    @State
    private var socialStats: SocialStats?

    @State
    private var hashtags: [Hashtag]?

    @State
    private var relationship: Relationship?

    private var identity: Identity {
        identityOrAbout.id
    }

    init(identity: Identity, style: CardStyle = .compact) {
        self.init(identityOrAbout: .left(identity), style: style)
    }

    init(about: About, style: CardStyle = .compact) {
        self.init(identityOrAbout: .right(about), style: style)
    }

    init(identityOrAbout: Either<Identity, About>, style: CardStyle = .compact) {
        self.identityOrAbout = identityOrAbout
        self.style = style
    }

    var body: some View {
        Group {
            switch style {
            case .compact:
                CompactIdentityView(
                    identity: identityOrAbout.id,
                    about: about,
                    socialStats: socialStats,
                    hashtags: hashtags,
                    relationship: relationship
                )
            case .golden:
                GoldenIdentityView(
                    identity: identityOrAbout.id,
                    about: about,
                    hashtags: hashtags
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { output in
            guard let notifiedRelationship = output.relationship, notifiedRelationship.other == identity else {
                return
            }
            relationship = notifiedRelationship
        }
        .task {
            loadAboutIfNeeded()
            loadRelationshipIfNeeded()
            loadHashtagsIfNeeded()
            loadSocialStatsIfNeeded()
        }
    }

    private func loadAboutIfNeeded() {
        guard about == nil else {
            return
        }
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.about(identity: identityToLoad)
                await MainActor.run {
                    about = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    about = About(about: identity)
                }
            }
        }
    }

    private func loadRelationshipIfNeeded() {
        guard relationship == nil, style == .compact else {
            return
        }
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            if let currentIdentity = bot.identity {
                do {
                    let result = try await bot.relationship(from: currentIdentity, to: identityToLoad)
                    await MainActor.run {
                        relationship = result
                    }
                } catch {
                    CrashReporting.shared.reportIfNeeded(error: error)
                    Log.shared.optional(error)
                }
            }
        }
    }

    private func loadHashtagsIfNeeded() {
        guard hashtags == nil else {
            return
        }
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.hashtags(usedBy: identityToLoad, limit: 3)
                await MainActor.run {
                    hashtags = result
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    hashtags = []
                }
            }
        }
    }

    private func loadSocialStatsIfNeeded() {
        guard socialStats == nil, style == .compact else {
            return
        }
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.socialStats(for: identityToLoad)
                await MainActor.run {
                    socialStats = result
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    socialStats = .zero
                }
            }
        }
    }
}
