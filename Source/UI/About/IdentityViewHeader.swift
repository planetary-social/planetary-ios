//
//  IdentityViewHeader.swift
//  Planetary
//
//  Created by Martin Dutra on 11/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct IdentityViewHeader: View {

    var identity: Identity
    var about: About?
    var extendedHeader: Bool

    @EnvironmentObject
    private var botRepository: BotRepository

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 18) {
                Circle()
                    .fill(
                        LinearGradient.diagonalAccent
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .frame(width: 92, height: 92)
                    .overlay(
                        AvatarView(metadata: about?.image, size: 87)
                    )
                    .onTapGesture {
                        guard let image = about?.image else {
                            return
                        }
                        AppController.shared.open(string: image.link)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text(about?.nameOrIdentity ?? identity)
                        .lineLimit(1)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(Color.primaryTxt)
                    HStack {
                        Text(identity.prefix(7))
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                    }
                    Group {
                        if botRepository.current.identity == identity {
                            Button {
                                AppController.shared.present(
                                    UINavigationController(
                                        rootViewController: EditAboutViewController(with: about)
                                    ),
                                    animated: true
                                )
                            } label: {
                                HStack(alignment: .center) {
                                    Image.buttonEditProfile
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 18)
                                    Text(Localized.editProfile.text)
                                        .font(.footnote)
                                        .foregroundLinearGradient(
                                            LinearGradient.horizontalAccent
                                        )
                                }
                                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .background(
                                    LinearGradient(
                                        colors: [.relationshipViewBg],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .cornerRadius(17)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17)
                                        .stroke(LinearGradient.horizontalAccent, lineWidth: 1)
                                )
                            }
                        } else {
                            RelationshipView(identity: identity)
                        }
                    }
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            if extendedHeader {
                if let bio = about?.description {
                    Text(bio.parseMarkdown())
                        .font(.subheadline)
                        .foregroundColor(.primaryTxt)
                        .accentColor(.accentTxt)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                        .lineLimit(10)
                } else if about == nil {
                    Text(String.loremIpsum(1))
                        .font(.subheadline)
                        .foregroundColor(.primaryTxt)
                        .redacted(reason: .placeholder)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                }
                HashtagSliderView(identity: identity)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 9, trailing: 0))
                SocialStatsView(identity: identity)
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
