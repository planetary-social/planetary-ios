//
//  RelationshipButton.swift
//  Planetary
//
//  Created by Martin Dutra on 22/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct RelationshipButton: View {

    var relationship: Relationship?
    var compact = false

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var isToggling = false

    private var isLoading: Bool {
        isToggling || relationship == nil
    }

    private var isFollowing: Bool {
        relationship?.isFollowing ?? false
    }

    private var isFollowedBy: Bool {
        relationship?.isFollowedBy ?? false
    }

    private var isBlocking: Bool {
        relationship?.isBlocking ?? false
    }

    var body: some View {
        Button {
            Analytics.shared.trackDidTapButton(buttonName: "follow")
            toggleRelationship()
        } label: {
            HStack(alignment: .center) {
                LinearGradient(
                    colors: foregroundColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ).mask {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(width: 18, height: 18)
                if !compact {
                    Text(title)
                        .font(.subheadline)
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
            .placeholder(when: isLoading) {
                HStack(alignment: .center) {
                    ProgressView().tint(Color.white).frame(width: 18, height: 18)
                    if !compact {
                        Text(Localized.loading.text)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .background(
                    Rectangle()
                        .fill(LinearGradient.horizontalAccent)
                        .cornerRadius(17)
                )
            }
        }
        .disabled(isLoading)
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private var star: Star? {
        let pubs = (AppConfiguration.current?.communityPubs ?? []) +
            (AppConfiguration.current?.systemPubs ?? [])
        return pubs.first { $0.feed == relationship?.other }
    }

    private var isStar: Bool {
        star != nil
    }

    private var title: String {
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

    private var image: Image {
        if isBlocking {
            return .buttonBlocking
        } else if isFollowing {
            return .buttonFollowing
        } else {
            return .buttonFollow
        }
    }

    private var backgroundColors: [Color] {
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

    private var foregroundColors: [Color] {
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

    private var borderColors: [Color] {
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

    private func toggleRelationship() {
        guard let relationshipToUpdate = relationship else {
            return
        }
        isToggling = true
        Task.detached {
            let bot = await botRepository.current
            let pubs = (AppConfiguration.current?.communityPubs ?? []) + (AppConfiguration.current?.systemPubs ?? [])
            let star = pubs.first { $0.feed == relationshipToUpdate.other }
            do {
                if let star = star {
                    try await bot.join(star: star)
                    Analytics.shared.trackDidFollowPub()
                    relationshipToUpdate.isFollowing = true
                } else if relationshipToUpdate.isBlocking {
                    try await bot.unblock(identity: relationshipToUpdate.other)
                    Analytics.shared.trackDidUnblockIdentity()
                    relationshipToUpdate.isBlocking = false
                } else {
                    if relationshipToUpdate.isFollowing {
                        try await bot.unfollow(identity: relationshipToUpdate.other)
                        Analytics.shared.trackDidUnfollowIdentity()
                        relationshipToUpdate.isFollowing = false
                    } else {
                        try await bot.follow(identity: relationshipToUpdate.other)
                        Analytics.shared.trackDidFollowIdentity()
                        relationshipToUpdate.isFollowing = true
                    }
                }
                await MainActor.run {
                    isToggling = false
                    NotificationCenter.default.post(
                        name: .didUpdateRelationship,
                        object: nil,
                        userInfo: [Relationship.infoKey: relationshipToUpdate]
                    )
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    isToggling = true
                    AppController.shared.alert(error: error)
                }
            }
        }
    }
}

struct RelationshipButton_Previews: PreviewProvider {
    static var follow: Relationship {
        Relationship(from: .null, to: .null)
    }
    static var followBack: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        relationship.isFollowedBy = true
        return relationship
    }
    static var following: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        relationship.isFollowing = true
        return relationship
    }
    static var blocking: Relationship {
        let relationship = Relationship(from: .null, to: .null)
        relationship.isBlocking = true
        return relationship
    }
    static var previews: some View {
        Group {
            VStack {
                RelationshipButton(relationship: nil)
                RelationshipButton(relationship: follow)
                RelationshipButton(relationship: followBack)
                RelationshipButton(relationship: following)
                RelationshipButton(relationship: blocking)
                RelationshipButton(relationship: nil, compact: true)
                RelationshipButton(relationship: follow, compact: true)
                RelationshipButton(relationship: followBack, compact: true)
                RelationshipButton(relationship: following, compact: true)
                RelationshipButton(relationship: blocking, compact: true)
            }
            VStack {
                RelationshipButton(relationship: nil)
                RelationshipButton(relationship: follow)
                RelationshipButton(relationship: followBack)
                RelationshipButton(relationship: following)
                RelationshipButton(relationship: blocking)
                RelationshipButton(relationship: nil, compact: true)
                RelationshipButton(relationship: follow, compact: true)
                RelationshipButton(relationship: followBack, compact: true)
                RelationshipButton(relationship: following, compact: true)
                RelationshipButton(relationship: blocking, compact: true)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
