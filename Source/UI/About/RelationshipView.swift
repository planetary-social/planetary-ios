//
//  RelationshipView.swift
//  Planetary
//
//  Created by Martin Dutra on 17/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

@MainActor
struct RelationshipView: View {

    var identity: Identity
    var compact = false

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    var isLoading = false

    @State
    var isFollowing = false

    @State
    var isFollowedBy = false

    @State
    var isBlocking = true

    var body: some View {
        Button {
            didTapButton()
        } label: {
            HStack(alignment: .center) {
                LinearGradient(
                    colors: foregroundColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ).mask {
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(width: 18, height: 18)
                if !compact {
                    Text(title)
                        .font(.footnote)
                        .foregroundLinearGradient(
                            LinearGradient(
                                colors: foregroundColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(17)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(
                        LinearGradient(colors: borderColors, startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
        }
        .placeholder(when: isLoading) {
            Rectangle()
                .fill(LinearGradient.horizontalAccent)
                .frame(width: compact ? 50 : 96, height: 33)
                .cornerRadius(17)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didBlockUser)) { output in
            guard let notifiedIdentity = output.object as? Identity, notifiedIdentity == identity else {
                return
            }
            isBlocking = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnblockUser)) { output in
            guard let notifiedIdentity = output.object as? Identity, notifiedIdentity == identity else {
                return
            }
            isBlocking = false
        }
        .task {
            Task.detached {
                let bot = await botRepository.current
                if let currentIdentity = bot.identity {
                    do {
                        let result = try await bot.relationship(from: currentIdentity, to: identity)
                        await MainActor.run {
                            isFollowing = result.isFollowing
                            isFollowedBy = result.isFollowedBy
                            isBlocking = result.isBlocking
                            isLoading = false
                        }
                    } catch {
                        CrashReporting.shared.reportIfNeeded(error: error)
                        Log.shared.optional(error)
                    }
                }
            }
        }
    }

    var star: Star? {
        let pubs = (AppConfiguration.current?.communityPubs ?? []) +
            (AppConfiguration.current?.systemPubs ?? [])
        return pubs.first { $0.feed == identity }
    }

    var isStar: Bool {
        star != nil
    }

    var title: String {
        guard !isLoading, !compact else {
            return ""
        }
        if isBlocking {
            return Localized.blocking.text
        } else if isFollowing {
            if isStar {
                return Localized.joined.text
            } else {
                return Localized.following.text
            }
        } else {
            if isStar {
                return Localized.join.text
            } else {
                if isFollowedBy {
                    return Localized.followBack.text
                } else {
                    return Localized.follow.text
                }
            }
        }
    }

    var image: String {
        guard !isLoading else {
            return ""
        }
        if isBlocking {
            return "button-blocking"
        } else if isFollowing {
            return "button-following"
        } else {
            return "button-follow"
        }
    }

    var backgroundColors: [Color] {
        guard !isLoading else {
            return []
        }
        if isBlocking {
            return [.relationshipViewBg]
        } else if isFollowing {
            return [.relationshipViewBg]
        } else {
            return [Color(hex: "#F08508"), Color(hex: "#F43F75")]
        }
    }

    var foregroundColors: [Color] {
        guard !isLoading else {
            return []
        }
        if isBlocking {
            return [Color(hex: "#F08508"), Color(hex: "#F43F75")]
        } else if isFollowing {
            return [Color(hex: "#F08508"), Color(hex: "#F43F75")]
        } else {
            return [.white]
        }
    }

    var borderColors: [Color] {
        guard !isLoading else {
            return []
        }
        if isBlocking {
            return [Color(hex: "#F08508"), Color(hex: "#F43F75")]
        } else if isFollowing {
            return [Color(hex: "#F08508"), Color(hex: "#F43F75")]
        } else {
            return [.clear]
        }
    }

    func didTapButton() {
        guard !isLoading else {
            return
        }
        Task.detached { [identity] in
            let bot = await botRepository.current
            Analytics.shared.trackDidTapButton(buttonName: "follow")
            do {
                if let star = await star {
                    try await bot.join(star: star)
                    Analytics.shared.trackDidFollowPub()
                    await MainActor.run {
                        isFollowing = true
                    }
                } else if await isBlocking {
                    try await bot.unblock(identity: identity)
                    Analytics.shared.trackDidUnblockIdentity()
                    await MainActor.run {
                        isBlocking = false
                    }
                } else {
                    if await isFollowing {
                        try await bot.unfollow(identity: identity)
                        Analytics.shared.trackDidUnfollowIdentity()
                        await MainActor.run {
                            isFollowing = false
                        }
                    } else {
                        try await bot.follow(identity: identity)
                        Analytics.shared.trackDidFollowIdentity()
                        await MainActor.run {
                            isFollowing = true
                        }
                    }
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    AppController.shared.alert(error: error)
                }
            }
        }
    }
}

struct RelationshipView_Previews: PreviewProvider {
    static var followRelationship: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        return relationship
    }
    static var followBackRelationship: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        relationship.isFollowedBy = true
        return relationship
    }
    static var followingRelationship: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        relationship.isFollowing = true
        return relationship
    }
    static var previews: some View {
        VStack {
            RelationshipView(identity: .null)
            RelationshipView(identity: .null, compact: true)
        }.background(Color.appBg).padding().previewLayout(.sizeThatFits).environmentObject(BotRepository.fake)

        VStack {
            RelationshipView(identity: .null)
            RelationshipView(identity: .null, compact: true)
        }.background(Color.appBg).padding().previewLayout(.sizeThatFits).preferredColorScheme(.dark).environmentObject(BotRepository.fake)
    }
}
