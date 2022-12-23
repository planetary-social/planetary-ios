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

struct IdentityHeaderView: View {

    var identity: Identity
    var aliases: [RoomAlias]?
    var about: About?
    var relationship: Relationship?
    var hashtags: [Hashtag]?
    var socialStats: ExtendedSocialStats?
    var extendedHeader: Bool

    @EnvironmentObject
    private var botRepository: BotRepository

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
                EditIdentityButton(about: about, compact: !extendedHeader)
            } else {
                RelationshipButton(relationship: relationship, compact: !extendedHeader)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 18) {
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        guard let image = about?.image else {
                            return
                        }
                        AppController.shared.open(string: image.link)
                    } label: {
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
                        HStack {
                            Text(aliases?.first?.alias ?? String(identity.prefix(7)))
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundColor(Color.secondaryTxt)
                            if let aliases, let count = aliases.count, count > 1 {
                                AliasCountButton(aliases: aliases, count: count - 1)
                            }
                        }
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
                ExtendedSocialStatsView(socialStats: socialStats)
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
}

// swiftlint:disable force_unwrapping
struct IdentityHeaderView_Previews: PreviewProvider {
    static var identity = Identity("@unset")
    static var aliases = [
        RoomAlias(
            id: 1,
            aliasURL: URL(string: "https://rose.techno.planetary")!,
            authorID: 1
        ),
        RoomAlias(
            id: 2,
            aliasURL: URL(string: "https://rose.fungi.planetary")!,
            authorID: 1
        )
    ]
    static var about: About {
        About(
            about: .null,
            name: "Rossina Simonelli",
            description: "This is a bio",
            imageLink: nil
        )
    }
    static var relationship: Relationship {
        Relationship(from: .null, to: .null)
    }
    static var socialStats: ExtendedSocialStats {
        ExtendedSocialStats(
            followers: [.null, .null],
            someFollowersAvatars: [nil, nil],
            follows: [.null, .null],
            someFollowsAvatars: [nil, nil],
            blocks: [],
            someBlocksAvatars: [],
            pubServers: [.null],
            somePubServersAvatars: [nil]
        )
    }
    static var hashtags: [Hashtag] {
        [Hashtag(name: "Design"), Hashtag(name: "Architecture"), Hashtag(name: "Chess")]
    }

    static var errorMessage: String?
    static var previews: some View {
        Group {
            VStack {
                IdentityHeaderView(
                    identity: identity,
                    aliases: nil,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: false
                )
                IdentityHeaderView(
                    identity: identity,
                    aliases: aliases,
                    about: nil,
                    relationship: nil,
                    hashtags: nil,
                    socialStats: nil,
                    extendedHeader: true
                )
                IdentityHeaderView(
                    identity: identity,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: true
                )
            }
            VStack {
                IdentityHeaderView(
                    identity: .null,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: false
                )
                IdentityHeaderView(
                    identity: .null,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: true
                )
            }
            VStack {
                IdentityHeaderView(
                    identity: identity,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: false
                )
                IdentityHeaderView(
                    identity: identity,
                    aliases: aliases,
                    about: nil,
                    relationship: nil,
                    hashtags: nil,
                    socialStats: nil,
                    extendedHeader: true
                )
                IdentityHeaderView(
                    identity: identity,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: true
                )
            }
            .preferredColorScheme(.dark)
            VStack {
                IdentityHeaderView(
                    identity: .null,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: false
                )
                IdentityHeaderView(
                    identity: .null,
                    aliases: aliases,
                    about: about,
                    relationship: relationship,
                    hashtags: hashtags,
                    socialStats: socialStats,
                    extendedHeader: true
                )
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
