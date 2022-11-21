//
//  IdentityViewHeader.swift
//  Planetary
//
//  Created by Martin Dutra on 11/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct IdentityViewHeader: View {

    var identity: Identity
    var about: About?
    var relationship: Relationship?
    var hashtags: [Hashtag]?
    var socialStats: ExtendedSocialStats?
    var extendedHeader: Bool

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    var isToggling = false

    private var shouldShowBio: Bool {
        if let about = about {
            return about.description?.isEmpty == false
        }
        return true
    }

    private var shouldShowHashtags: Bool {
        if let hashtags = hashtags {
            return !hashtags.isEmpty
        }
        return true
    }

    private var isSelf: Bool {
        botRepository.current.identity == identity
    }

    private var followButton: some View {
        Group {
            if isSelf {
                EditIdentityButton(about: about)
            } else {
                Button {
                    Analytics.shared.trackDidTapButton(buttonName: "follow")
                    toggleRelationship()
                } label: {
                    RelationshipLabel(relationship: isToggling ? nil : relationship, compact: !extendedHeader)
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 18) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if extendedHeader {
                            AvatarView(metadata: about?.image, size: 87)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 99)
                                        .stroke(LinearGradient.diagonalAccent, lineWidth: 3)
                                )
                        } else {
                            AvatarView(metadata: about?.image, size: 45)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 99)
                                        .stroke(LinearGradient.diagonalAccent, lineWidth: 2)
                                )
                        }
                    }
                    .onTapGesture {
                        guard let image = about?.image else {
                            return
                        }
                        AppController.shared.open(string: image.link)
                    }
                    if isSelf {
                        EditAvatarButton(about: about, large: extendedHeader)
                    }
                }
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(about?.nameOrIdentity ?? identity)
                            .lineLimit(1)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color.primaryTxt)
                        Text(identity.prefix(7))
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                        if extendedHeader {
                            followButton
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !extendedHeader {
                        followButton
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            if extendedHeader {
                if shouldShowBio {
                    BioView(bio: about?.description)
                }
                if shouldShowHashtags {
                    HashtagSliderView(hashtags: hashtags)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 9, trailing: 0))
                }
                SocialStatsView(socialStats: socialStats)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.profileBgTop, Color.profileBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .compositingGroup()
        .shadow(color: .profileShadow, radius: 10, x: 0, y: 4)
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

struct IdentityViewHeader_Previews: PreviewProvider {
    static var sample: About {
        return About(
            about: .null,
            name: "Rossina Simonelli",
            description: "This is a bio",
            imageLink: nil
        )
    }
    static var errorMessage: String?
    static var previews: some View {
        VStack {
            IdentityViewHeader(identity: .null, about: sample, extendedHeader: false)
            IdentityViewHeader(identity: .null, about: sample, extendedHeader: true)
        }
        .environmentObject(BotRepository.shared)
        .previewLayout(.sizeThatFits)
    }
}

