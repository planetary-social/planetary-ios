//
//  IdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 23/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A view model for the RawMessageView
@MainActor protocol IdentityViewModel: ObservableObject {

    var identity: Identity { get }

    var about: About? { get }

    var socialStats: ExtendedSocialStats? { get }

    var relationship: Relationship? { get }

    var hashtags: [Hashtag]? { get }

    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }

    /// Called when the user dismisses the shown error message. Should clear `errorMessage`.
    func didDismissError()

    /// Called when the user taps on the Cancel button
    func didDismiss()

    func followButtonTapped()

    func block()

    func report()

    func hashtagTapped(_ hashtag: Hashtag)

    func socialTraitTapped(_ trait: SocialStatsView.Trait)

    func sharePublicIdentifier()

    func shareThisProfile()
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }

    typealias Value = CGFloat
}

struct IdentityView<ViewModel>: View where ViewModel: IdentityViewModel {
    @ObservedObject var viewModel: ViewModel
    @State private var showingShareOptions = false
    @State private var showingActionOptions = false
    @State private var extendedHeader = true
    @State private var oldScrollViewOffset = ScrollViewOffsetPreferenceKey.defaultValue

    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }

    var header: some View {
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
                        ImageMetadataView(metadata: viewModel.about?.image)
                            .cornerRadius(99)
                            .frame(width: 87, height: 87)
                            .scaledToFill()
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.about?.nameOrIdentity ?? viewModel.identity)
                        .foregroundColor(Color("primary-txt"))
                        .font(.system(size: 20, weight: .semibold))
                    HStack {
                        Text(viewModel.identity.prefix(7))
                            .font(.system(size: 12))
                            .foregroundColor(Color("secondary-txt"))
                    }
                    RelationshipView(relationship: viewModel.relationship) {
                        viewModel.followButtonTapped()
                    }
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            if extendedHeader {
                if let bio = viewModel.about?.description {
                    Text(bio.parseMarkdown())
                        .font(.system(size: 14))
                        .foregroundColor(Color("primary-txt"))
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                        .lineLimit(10)
                } else if viewModel.about == nil {
                    Text(String.loremIpsum(1))
                        .font(.system(size: 14))
                        .foregroundColor(Color("primary-txt"))
                        .redacted(reason: .placeholder)
                        .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                }
                Text("Last active: 3 days ago")
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

                SocialStatsView(socialStats: viewModel.socialStats ?? .zero) { trait in
                    viewModel.socialTraitTapped(trait)
                }
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
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(
                        key: ScrollViewOffsetPreferenceKey.self,
                        value: offset
                    )
                    .frame(height: 0)
                    .border(Color.red)
                }.frame(height: 0)
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    Section(
                        header: header,
                        content: {
                            ForEach((0...100).reversed(), id: \.self) {_ in
                                Text("Hello").background(.clear).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    )
                }
            }
        }
        .background(Color("app-bg"))
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            if value < 0 {
                if oldScrollViewOffset >= 0 {
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            } else {
                if oldScrollViewOffset < 0 {
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            }
            oldScrollViewOffset = value
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingShareOptions = true
                } label: {
                    Image("icon-share")
                }
                .confirmationDialog(Localized.share.text, isPresented: $showingShareOptions) {
                    Button(Localized.sharePublicIdentifier.text) {
                        viewModel.sharePublicIdentifier()
                    }
                    Button(Localized.shareThisProfile.text) {
                        viewModel.shareThisProfile()
                    }
                }
                Button {
                    showingActionOptions = true
                } label: {
                    Image("icon-options-off")
                }
                .confirmationDialog(Localized.share.text, isPresented: $showingActionOptions) {
                    Button(Localized.blockUser.text, role: .destructive) {
                        viewModel.block()
                    }
                    Button(Localized.reportUser.text, role: .destructive) {
                        viewModel.report()
                    }
                }
            }
        }
        .alert(isPresented: showAlert) {
            Alert(title: Localized.error.view, message: SwiftUI.Text(viewModel.errorMessage ?? ""))
        }
        .onPreferenceChange(OffsetKey.self) {
            extendedHeader = ($0 ?? 0) < 143
        }
    }
}

fileprivate struct OffsetKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

fileprivate class PreviewViewModel: IdentityViewModel {

    @Published var identity: Identity
    @Published var about: About?
    @Published var socialStats: ExtendedSocialStats?
    @Published var hashtags: [Hashtag]?
    @Published var relationship: Relationship?
    @Published var errorMessage: String?

    init(identity: Identity) {
        self.identity = identity
    }

    static var zero: PreviewViewModel {
        PreviewViewModel(identity: .null)
    }

    static var sample: PreviewViewModel {
        let viewModel = PreviewViewModel(identity: .null)
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        Caches.blobs.update(UIImage(named: "avatar2") ?? .remove, for: "&avatar2")
        Caches.blobs.update(UIImage(named: "avatar3") ?? .remove, for: "&avatar3")
        Caches.blobs.update(UIImage(named: "avatar4") ?? .remove, for: "&avatar4")
        Caches.blobs.update(UIImage(named: "avatar5") ?? .remove, for: "&avatar5")
        viewModel.hashtags = [Hashtag(name: "Architecture"), Hashtag(name: "Design")]
        viewModel.about = About(
            identity: .null,
            name: "Rossina Simonelli",
            description: "Engineer at Webflow. Love electronic music and futuristic landscapes. "
                + "Help others, live 2 enjoy. Quality, not quantity.",
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

    func didDismissError() {}
    func didDismiss() {}
    func hashtagTapped(_ hashtag: Hashtag) { }
    func followButtonTapped() { }
    func shareThisProfile() { }
    func block() { }
    func report() { }
    func sharePublicIdentifier() { }
    func socialTraitTapped(_ trait: SocialStatsView.Trait) { }
}

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            IdentityView(viewModel: PreviewViewModel.zero)
        }
        .preferredColorScheme(.light)

        NavigationView {
            IdentityView(viewModel: PreviewViewModel.sample)
        }
        .preferredColorScheme(.light)

        NavigationView {
            IdentityView(viewModel: PreviewViewModel.sample)
        }
        .preferredColorScheme(.dark)
    }
}
