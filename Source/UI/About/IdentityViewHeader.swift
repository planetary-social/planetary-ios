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

    @State
    private var showingBio = false

    @State
    private var shouldShowReadMore = false

    @State
    private var intrinsicSize = CGSize.zero

    @State
    private var truncatedSize = CGSize.zero

    func updateShouldShowReadMore() {
        shouldShowReadMore = intrinsicSize != truncatedSize
    }

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
                        .lineLimit(5)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                        .background {
                            GeometryReader { geometryProxy in
                                Color.clear.preference(key: TruncatedSizePreferenceKey.self, value: geometryProxy.size)
                            }
                        }
                        .onPreferenceChange(TruncatedSizePreferenceKey.self) { newSize in
                            if newSize.height > truncatedSize.height {
                                truncatedSize = newSize
                                updateShouldShowReadMore()
                            }
                        }
                        .background {
                            Text(bio.parseMarkdown())
                                .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                                .fixedSize(horizontal: false, vertical: true)
                                .hidden()
                                .background {
                                    GeometryReader { geometryProxy in
                                        Color.clear.preference(key: IntrinsicSizePreferenceKey.self, value: geometryProxy.size)
                                    }
                                }
                                .onPreferenceChange(IntrinsicSizePreferenceKey.self) { newSize in
                                    if newSize.height > intrinsicSize.height {
                                        intrinsicSize = newSize
                                        updateShouldShowReadMore()
                                    }
                                }
                        }
                        .onTapGesture {
                            showingBio = true
                        }
                        .sheet(isPresented: $showingBio) {
                            extendedBio(bio: bio, isPresented: $showingBio)
                        }
                } else if about == nil {
                    Text(String.loremIpsum(1))
                        .lineLimit(5)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                        .redacted(reason: .placeholder)
                }
                if shouldShowReadMore {
                    ZStack(alignment: .center) {
                        Text(Localized.readMore.text.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondaryTxt)
                            .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                            .background(Color.hashtagBg)
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .onTapGesture {
                        showingBio = true
                    }
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

    private func extendedBio(bio: String, isPresented: Binding<Bool>) -> some View {
        NavigationView {
            SelectableText(bio.parseMarkdown())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cardBackground)
            .navigationTitle(Localized.bio.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented.wrappedValue = false
                    } label: {
                        Image.navIconDismiss
                    }
                }
            }
        }
    }

    fileprivate struct IntrinsicSizePreferenceKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
    }

    fileprivate struct TruncatedSizePreferenceKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
    }
}
