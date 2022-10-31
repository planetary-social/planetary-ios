//
//  RelationshipView.swift
//  Planetary
//
//  Created by Martin Dutra on 17/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct RelationshipView: View {
    var relationship: Relationship?
    var compact = false
    var onButtonTapHandler: (() -> Void)?

    var body: some View {
        Button {
            onButtonTapHandler?()
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
                    SwiftUI.Text(title)
                        .font(.system(size: 13))
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
                        LinearGradient(colors: foregroundColors, startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
        }
        .placeholder(when: relationship == nil) {
            Rectangle().fill(
                LinearGradient(
                    colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: compact ? 50 : 96, height: 33)
            .cornerRadius(17)
        }
    }

    var title: String {
        guard let relationship = relationship, !compact else {
            return ""
        }
        if relationship.isFollowing {
            return Localized.following.text
        } else {
            if relationship.isFollowedBy {
                return Localized.followBack.text
            } else {
                return Localized.follow.text
            }
        }
    }

    var image: String {
        guard let relationship = relationship else {
            return ""
        }
        if relationship.isFollowing {
            return "button-following"
        } else {
            return "button-follow"
        }
    }

    var backgroundColors: [Color] {
        guard let relationship = relationship else {
            return []
        }
        return relationship.isFollowing ? [.clear] : [Color(hex: "#F08508"), Color(hex: "#F43F75")]
    }

    var foregroundColors: [Color] {
        guard let relationship = relationship else {
            return []
        }
        return relationship.isFollowing ? [Color(hex: "#F08508"), Color(hex: "#F43F75")] : [.white]
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
            RelationshipView(relationship: nil, compact: true)
            RelationshipView(relationship: followRelationship, compact: true)
            RelationshipView(relationship: followRelationship)
            RelationshipView(relationship: followBackRelationship)
            RelationshipView(relationship: followingRelationship)
        }.padding().previewLayout(.sizeThatFits)
    }
}
