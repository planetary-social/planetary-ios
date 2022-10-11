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

    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get }

    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }

    /// Called when the user dismisses the shown error message. Should clear `errorMessage`.
    func didDismissError()

    /// Called when the user taps on the Cancel button
    func didDismiss()

    func followButtonTapped()

    func hashtagTapped(_ hashtag: Hashtag)

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
    @State private var showingOptions = false
    @State private var extendedHeader = true
    @State private var oldScrollViewOffset = ScrollViewOffsetPreferenceKey.defaultValue

    /// A loading overlay that displays the `loadingMessage` from the view model.
    private var loadingIndicator: some View {
        VStack {
            Spacer()
            if showProgress, let loadingMessage = viewModel.loadingMessage {
                VStack {
                    PeerConnectionAnimationView(peerCount: 5)
                    SwiftUI.Text(loadingMessage)
                        .foregroundColor(Color("mainText"))
                }
                .padding(16)
                .cornerRadius(8)
                .background(Color("cardBackground").cornerRadius(8))
            } else {
                EmptyView()
            }
            Spacer()
        }
    }

    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }

    private var showProgress: Bool {
        viewModel.loadingMessage?.isEmpty == false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: offset).frame(height: 0).border(Color.red)
                }.frame(height: 0)
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    Section(
                        header: IdentityHeaderView(
                            viewModel: viewModel,
                            extended: extendedHeader
                        ).compositingGroup().shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4),
                        content: {
                            ForEach((0...100).reversed(), id: \.self) {_ in
                                SwiftUI.Text("Hello")
                                    .background(.clear)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    print("toggle")
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            } else {
                if oldScrollViewOffset < 0 {
                    print("toggle")
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            }
            oldScrollViewOffset = value
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(showProgress)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingOptions = true
                } label: {
                    Image("icon-share")
                }
                .confirmationDialog(Localized.share.text, isPresented: $showingOptions) {
                    Button(Localized.sharePublicIdentifier.text) {
                        viewModel.sharePublicIdentifier()
                    }
                    Button(Localized.shareThisProfile.text) {
                        viewModel.shareThisProfile()
                    }
                }
                Button {
                    viewModel.didDismiss()
                } label: {
                    Image("icon-options-off")
                }
            }
        }
        .overlay(loadingIndicator)
        .alert(isPresented: showAlert) {
            Alert(
                title: Localized.error.view,
                message: SwiftUI.Text(viewModel.errorMessage ?? "")
            )
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

    @Published var loadingMessage: String?

    @Published var errorMessage: String?

    init() {
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        Caches.blobs.update(UIImage(named: "avatar2") ?? .remove, for: "&avatar2")
        Caches.blobs.update(UIImage(named: "avatar3") ?? .remove, for: "&avatar3")
        Caches.blobs.update(UIImage(named: "avatar4") ?? .remove, for: "&avatar4")
        Caches.blobs.update(UIImage(named: "avatar5") ?? .remove, for: "&avatar5")
        self.identity = Identity("@gS5dt87asd1")
        self.about = About(
            identity: .null,
            name: "Rossina Simonelli",
            description: "Engineer at Webflow. Love electronic music and futuristic landscapes. Help others, live 2 enjoy. Quality, not quantity.",
            image: ImageMetadata(link: "&avatar3"),
            publicWebHosting: nil
        )
        self.hashtags = [Hashtag(name: "Architecture"), Hashtag(name: "SocialMedia"), Hashtag(name: "Design")]
        self.socialStats = ExtendedSocialStats(
            numberOfFollowers: 44,
            followers: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar2")],
            numberOfFollows: 168,
            follows: [ImageMetadata(link: "&avatar4"), ImageMetadata(link: "&avatar5")],
            numberOfBlocks: 32,
            blocks: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar2")],
            numberOfPubServers: 7,
            pubServers: [ImageMetadata(link: "&avatar4"), ImageMetadata(link: "&avatar5")]
        )
        self.relationship = Relationship(from: .null, to: .null)
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

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            IdentityView(viewModel: PreviewViewModel())
        }
        .previewDevice("iPhone 13")
        .preferredColorScheme(.light)
        .previewInterfaceOrientation(.portrait)
        NavigationView {
            IdentityView(viewModel: PreviewViewModel())
        }
        .preferredColorScheme(.dark)
    }
}
