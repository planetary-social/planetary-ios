//
//  PreviewView.swift
//  Planetary
//
//  Created by Martin Dutra on 10/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct PreviewView: View {

    /// The text of the Post
    var text: String

    /// The photos attached in the Post
    var photos: [UIImage]

    /// The root message (if it is a reply)
    var root: Message?

    /// A Binding used to close the modal containing this view
    @Binding
    var isPresenting: Bool

    /// If true, it will show a LoadingView and disable hit testing in other views
    @State
    private var isLoading = false

    /// A State holding the information for the current logged in user
    @State
    private var about: About?

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var localizedError: Error?

    @State
    private var showResetForkedFeedConfirmationDialog = false

    var body: some View {
        ZStack {
            VStack {
                ScrollView(.vertical) {
                    ZStack(alignment: .top) {
                        if let root = root {
                            ZStack {
                                MessageButton(
                                    message: root,
                                    style: .compact,
                                    shouldDisplayChain: false
                                )
                                .allowsHitTesting(false)
                                .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                .opacity(0.7)
                            }
                            .frame(height: 100, alignment: .top)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .center) {
                                HStack(alignment: .center) {
                                    if let about = about {
                                        AvatarView(metadata: about.image, size: 24)
                                        if let header = attributedHeader {
                                            Text(header)
                                                .lineLimit(1)
                                                .font(.subheadline)
                                                .foregroundColor(Color.secondaryTxt)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(text.parseMarkdown())
                                    .allowsHitTesting(false)
                                    .font(.body)
                                    .foregroundColor(.primaryTxt)
                                    .accentColor(.accent)
                                    .padding(15)
                                if !photos.isEmpty {
                                    TabView {
                                        if photos.isEmpty {
                                            Spacer()
                                        } else {
                                            ForEach(photos, id: \.self) { photo in
                                                Image(uiImage: photo)
                                                    .resizable()
                                                    .scaledToFill()
                                            }
                                        }
                                    }
                                    .tabViewStyle(.page)
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                            HStack {
                                Spacer()
                                Image.buttonReply
                                Image.iconLike
                            }
                            .padding(15)
                        }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button(Localized.postAction.text) {
                                    Analytics.shared.trackDidTapButton(buttonName: "post")
                                    publishPost()
                                }
                                .allowsHitTesting(!isLoading)
                            }
                        }
                        .background(
                            LinearGradient.cardGradient
                        )
                        .cornerRadius(20)
                        .offset(y: root == nil ? 0 : 100)
                        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
                        .compositingGroup()
                        .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
                        .shadow(
                            color: .cardShadowBottom,
                            radius: 10,
                            x: 0,
                            y: 4
                        )
                        Spacer()
                    }
                }
            }
            if isLoading {
                LoadingView(text: Localized.NewPost.publishing.text)
            }
        }
        .alert(
            Localized.error.text,
            isPresented: .constant(localizedError != nil),
            actions: {
                if let error = localizedError as? BotError, error == .forkProtection {
                    Button(Localized.ForkedFeedProtection.prepareForReset.text) {
                        localizedError = nil
                        showResetForkedFeedConfirmationDialog = true
                    }
                    if let url = URL(string: "https://github.com/planetary-social/planetary-ios/wiki/Forked-Feed") {
                        Button(Localized.ForkedFeedProtection.readMore.text) {
                            localizedError = nil
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button(Localized.cancel.text, role: .cancel) {
                    localizedError = nil
                }
            },
            message: {
                Text(localizedError?.localizedDescription ?? "")
            }
        )
        .confirmationDialog(
            Localized.ForkedFeedProtection.resetForkedFeedProtection.text,
            isPresented: $showResetForkedFeedConfirmationDialog,
            titleVisibility: .visible,
            actions: {
                Button(Localized.ForkedFeedProtection.reset.text, role: .destructive) {
                    showResetForkedFeedConfirmationDialog = false
                    Task.detached(priority: .userInitiated) {
                        let bot = await botRepository.current
                        do {
                            try await bot.resetForkedFeedProtection()
                        } catch {
                            await MainActor.run {
                                localizedError = error
                            }
                        }
                    }
                }
                Button(Localized.cancel.text, role: .cancel) {
                    showResetForkedFeedConfirmationDialog = false
                }
            }
        )
        .navigationTitle(Localized.preview.text)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBg)
        .task {
            if about == nil {
                loadAbout()
            }
        }
    }

    func loadAbout() {
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            do {
                let currentAbout = try await bot.about()
                await MainActor.run {
                    about = currentAbout
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.optional(error)
            }
        }
    }

    func publishPost() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            let text = await text
            let photos = await photos
            let root = await root
            do {
                let post: Post
                if let root = root {
                    post = Post(text: text, root: root.key, branches: [root.key])
                } else {
                    post = Post(text: text)
                }
                try await bot.publish(post, with: photos)
                Analytics.shared.trackDidPost(characterCount: text.count)
                await MainActor.run {
                    NotificationCenter.default.post(.didPublishPost(post))
                    isLoading = false
                    isPresenting = false
                    try? StoreReviewController.promptIfConditionsMet()
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    isLoading = false
                    localizedError = error as? LocalizedError
                }
            }
        }
    }

    private var attributedHeader: AttributedString? {
        let localized = root == nil ? Localized.posted : Localized.replied
        let displayName = about?.displayName ?? "You"
        let string = localized.text(["somebody": "**\(displayName)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: displayName) {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }
}

struct PreviewView_Previews: PreviewProvider {
    static var messageValue: MessageValue {
        MessageValue(
            author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            content: Content(
                from: Post(
                    blobs: nil,
                    branches: nil,
                    hashtags: nil,
                    mentions: nil,
                    root: "%somepost",
                    text: .loremIpsum(words: 10)
                )
            ),
            hash: "",
            previous: nil,
            sequence: 0,
            signature: .null,
            claimedTimestamp: 0
        )
    }
    static var message: Message {
        var message = Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(count: 0, abouts: Set()),
            isPrivate: false
        )
        return message
    }

    @State
    static var isPresenting = false

    static var previews: some View {
        NavigationView {
            PreviewView(text: "Hey ", photos: [], root: message, isPresenting: $isPresenting)
        }
        .injectAppEnvironment(botRepository: .fake)
    }
}
