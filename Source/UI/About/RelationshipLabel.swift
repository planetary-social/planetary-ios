//
//  RelationshipLabel.swift
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
struct RelationshipLabel: View {

    var relationship: Relationship?
    var compact = false

    private var isLoading: Bool {
        relationship == nil
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

    var star: Star? {
        let pubs = (AppConfiguration.current?.communityPubs ?? []) +
            (AppConfiguration.current?.systemPubs ?? [])
        return pubs.first { $0.feed == relationship?.other }
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
}

struct RelationshipLabel_Previews: PreviewProvider {
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
        VStack {
            RelationshipLabel(relationship: nil)
            RelationshipLabel(relationship: follow)
            RelationshipLabel(relationship: followBack)
            RelationshipLabel(relationship: following)
            RelationshipLabel(relationship: blocking)
            RelationshipLabel(relationship: nil, compact: true)
            RelationshipLabel(relationship: follow, compact: true)
            RelationshipLabel(relationship: followBack, compact: true)
            RelationshipLabel(relationship: following, compact: true)
            RelationshipLabel(relationship: blocking, compact: true)
        }.padding().background(Color.appBg)

        VStack {
            RelationshipLabel(relationship: nil)
            RelationshipLabel(relationship: follow)
            RelationshipLabel(relationship: followBack)
            RelationshipLabel(relationship: following)
            RelationshipLabel(relationship: blocking)
            RelationshipLabel(relationship: nil, compact: true)
            RelationshipLabel(relationship: follow, compact: true)
            RelationshipLabel(relationship: followBack, compact: true)
            RelationshipLabel(relationship: following, compact: true)
            RelationshipLabel(relationship: blocking, compact: true)
        }.padding().background(Color.appBg).preferredColorScheme(.dark)
    }
}
