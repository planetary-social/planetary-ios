//
//  IdentityHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 4/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct IdentityHeaderView<ViewModel>: View where ViewModel: IdentityViewModel {

    @ObservedObject var viewModel: ViewModel
    var extended: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 18) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .frame(width: 92, height: 92)
                    .overlay(
                        AvatarImageViewRepresentable(metadata: viewModel.about?.image, animated: true)
                            .scaledToFit()
                            .frame(width: 87, height: 87)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    SwiftUI.Text(viewModel.about?.nameOrIdentity ?? viewModel.identity)
                        .foregroundColor(Color("primary-txt"))
                        .font(.system(size: 20, weight: .semibold))
                    HStack {
                        SwiftUI.Text(viewModel.identity.prefix(7))
                            .font(.system(size: 12))
                            .foregroundColor(Color("secondary-txt"))
                    }
                    if let relationship = viewModel.relationship {
                        Button {
                            viewModel.followButtonTapped()
                        } label: {
                            Label(Localized.follow.text, image: "button-follow")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white)
                                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .cornerRadius(17)
                                )
                        }
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    } else {
                        Rectangle().fill(
                            LinearGradient(
                                colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 96, height: 33)
                        .cornerRadius(17)
                        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            if extended {
                if let bio = viewModel.about?.description {
                    SwiftUI.Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(Color("primary-txt"))
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                } else if viewModel.about == nil {
                    SwiftUI.Text(String.loremIpsum(1))
                        .font(.system(size: 14))
                        .foregroundColor(Color("primary-txt"))
                        .redacted(reason: .placeholder)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                }
                SwiftUI.Text("Last active: 3 days ago")
                    .font(.system(size: 10))
                    .foregroundColor(Color("secondary-txt"))
                    .padding(EdgeInsets(top: 2, leading: 5, bottom: 3, trailing: 5))
                    .background(Color("hashtag-bg"))
                    .cornerRadius(3)
                    .padding(EdgeInsets(top: 0, leading: 18, bottom: 7, trailing: 18))
                    .redacted(reason: viewModel.relationship == nil ? .placeholder : [])

                if !(viewModel.hashtags?.isEmpty ?? false) {
                    HashtagSliderView(hashtags: viewModel.hashtags ?? []) { hashtag in
                        viewModel.hashtagTapped(hashtag)
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 9, trailing: 0))
                    .redacted(reason: viewModel.hashtags == nil ? .placeholder : [])
                }

                SocialStatsView(socialStats: viewModel.socialStats ?? .zero)
                .frame(maxWidth: .infinity)
                .redacted(reason: viewModel.socialStats == nil ? .placeholder : [])
            }
        }
        .background(
            LinearGradient(
                colors: [Color("profile-bg-top"), Color("profile-bg-bottom")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

fileprivate class PreviewViewModel: IdentityViewModel {

    @Published var identity: Identity

    @Published var about: About?

    @Published var socialStats: ExtendedSocialStats?

    @Published var relationship: Relationship?

    @Published var hashtags: [Hashtag]?

    @Published var loadingMessage: String?

    @Published var errorMessage: String?

    init(identity: Identity) {
        self.identity = identity
    }

    static var zero: PreviewViewModel {
        PreviewViewModel(identity: .null)
    }

    static var sample: PreviewViewModel {
        var viewModel = PreviewViewModel(identity: .null)
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        Caches.blobs.update(UIImage(named: "avatar2") ?? .remove, for: "&avatar2")
        Caches.blobs.update(UIImage(named: "avatar3") ?? .remove, for: "&avatar3")
        Caches.blobs.update(UIImage(named: "avatar4") ?? .remove, for: "&avatar4")
        Caches.blobs.update(UIImage(named: "avatar5") ?? .remove, for: "&avatar5")
        viewModel.hashtags = [Hashtag(name: "Architecture"), Hashtag(name: "Design")]
        viewModel.about = About(
            identity: .null,
            name: "Rossina Simonelli",
            description: "Engineer at Webflow. Love electronic music and futuristic landscapes. Help others, live 2 enjoy. Quality, not quantity.",
            image: ImageMetadata(link: "&avatar3"),
            publicWebHosting: nil
        )
        viewModel.socialStats = ExtendedSocialStats(
            numberOfFollowers: 2,
            followers: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3")],
            numberOfFollows: 1,
            follows: [ImageMetadata(link: "&avatar4")],
            numberOfBlocks: 3,
            blocks: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3"), ImageMetadata(link: "&avatar4")],
            numberOfPubServers: 0,
            pubServers: []
        )
        viewModel.relationship = Relationship(from: .null, to: .null)
        return viewModel
    }

    private func loadAbout() {
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.hashtags = [Hashtag(name: "Architecture"), Hashtag(name: "Design")]
                self.about = About(
                    identity: .null,
                    name: "Rossina Simonelli",
                    description: "Engineer at Webflow. Love electronic music and futuristic landscapes. Help others, live 2 enjoy. Quality, not quantity.",
                    image: ImageMetadata(link: "&avatar3"),
                    publicWebHosting: nil
                )
                self.socialStats = ExtendedSocialStats(
                    numberOfFollowers: 2,
                    followers: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3")],
                    numberOfFollows: 1,
                    follows: [ImageMetadata(link: "&avatar4")],
                    numberOfBlocks: 3,
                    blocks: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3"), ImageMetadata(link: "&avatar4")],
                    numberOfPubServers: 0,
                    pubServers: []
                )
                self.relationship = Relationship(from: .null, to: .null)
            }
        }
    }

    func didDismissError() {}

    func didDismiss() {}

    func hashtagTapped(_ hashtag: Hashtag) { }

    func followButtonTapped() { }

    func shareThisProfile() {

    }

    func sharePublicIdentifier() {

    }


}

struct IdentityHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        IdentityHeaderView(viewModel: PreviewViewModel.zero, extended: true)
            .previewLayout(.sizeThatFits)

        IdentityHeaderView(viewModel: PreviewViewModel.sample, extended: true)
            .previewLayout(.sizeThatFits)

    }
}
