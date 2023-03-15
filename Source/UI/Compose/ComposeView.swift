//
//  ComposeView.swift
//  Planetary
//
//  Created by Martin Dutra on 9/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Analytics
import Combine
import CrashReporting
import Logger
import PhotosUI
import SwiftUI

struct ComposeView: View {

    /// Binding used to dimiss this view
    @Binding
    var isPresenting: Bool

    /// State holding the text the user is typing
    @StateObject
    private var textEditorObserver = TextEditorObserver()

    /// State containing the very last state before `text` changes
    ///
    /// We need this so that we can compare and decide what has changed.
    @State
    private var oldText: String = ""

    /// State containing the photos the user is attaching
    @State
    private var photos: [UIImage] = []

    /// State containing the offset (index) of text when the user is mentioning someone
    ///
    /// When we detect the user typed a '@', we save the position of that character here and open a screen
    /// that lets the user select someone to mention, then we can replace this character with the full mention.
    @State
    private var mentionOffset: Int?

    /// State used to present or hide a confirmation dialog that lets the user remove an attached photo.
    @State
    private var showDeleteAttachmentConfirmation = false

    private var showAvailableMentions: Binding<Bool> {
        Binding {
            mentionOffset != nil
        } set: { _ in
            mentionOffset = nil
        }
    }

    /// List containing possible identities the user can mention.
    @State
    private var followings: [Identity]?

    /// If true, we already attempted to load a draft from disk
    ///
    /// We need this because the `task` modifier can be invoked multiple times if the user goes back from Preview.
    @State
    private var draftLoaded = false

    @EnvironmentObject
    private var botRepository: BotRepository

    /// Used to maintain focus on the text editor when the keyboard is dismissed or the screen appears
    @FocusState
    private var textEditorIsFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $textEditorObserver.text)
                    .focused($textEditorIsFocused)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.primaryTxt)
                    .onChange(of: textEditorObserver.text) { newValue in
                        let difference = newValue.difference(from: oldText)
                        guard difference.count == 1, let change = difference.first else {
                            oldText = newValue
                            return
                        }
                        switch change {
                        case .insert(let offset, let element, _):
                            if element == "@", followings != nil {
                                mentionOffset = offset
                            }
                        default:
                            break
                        }
                        oldText = newValue
                    }
                    .sheet(isPresented: showAvailableMentions) {
                        NavigationStack {
                            IdentityListView(identities: followings ?? []) { identity in
                                Task.detached(priority: .userInitiated) {
                                    guard let offset = await mentionOffset else {
                                        return
                                    }
                                    let textToModify = await textEditorObserver.text
                                    let link: String
                                    do {
                                        let about = try await botRepository.current.about(identity: identity)
                                        if let name = about?.name {
                                            link = "[\(name)](\(identity))"
                                        } else {
                                            link = "[\(identity)](\(identity))"
                                        }
                                    } catch {
                                        link = "[\(identity)](\(identity))"
                                    }
                                    var modifiedString = String()
                                    for (i, char) in textToModify.enumerated() {
                                        modifiedString += (i == offset) ? "\(link) " : String(char)
                                    }
                                    await MainActor.run { [modifiedString] in
                                        textEditorObserver.text = modifiedString
                                        oldText = modifiedString
                                        mentionOffset = nil
                                    }
                                }
                            }
                            .navigationTitle(Localized.NewPost.mention.text)
                        }
                        .presentationDetents([.medium, .large])
                    }
                VStack(spacing: 0) {
                    if !photos.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 5) {
                                ForEach(photos, id: \.self) { photo in
                                    AttachedImageButton(image: photo) { image in
                                        guard let index = photos.firstIndex(where: { $0 === image }) else {
                                            return
                                        }
                                        photos.remove(at: index)
                                        saveDraft()
                                    }
                                }
                            }
                            .padding(5)
                        }
                    }
                    Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                    HStack {
                        ImagePickerButton { image in
                            photos.append(image)
                            saveDraft()
                        } label: {
                            Image.iconLibrary
                        }
                        .padding(10)
                        Spacer()
                        NavigationLink {
                            PreviewView(
                                text: textEditorObserver.text,
                                photos: photos,
                                isPresenting: $isPresenting
                            )
                            .task {
                                saveDraft()
                            }
                        } label: {
                            Text(Localized.preview.text)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .background(
                                    Rectangle()
                                        .fill(LinearGradient.horizontalAccent)
                                        .cornerRadius(17)
                                )
                        }
                        .padding(10)
                    }
                    Color.cardBgBottom.ignoresSafeArea(.all, edges: .bottom).frame(height: 0)
                }
                .background {
                    LinearGradient.cardGradient
                }
            }
            .background {
                Color.appBg
            }
            .navigationTitle(Localized.newPost.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        saveDraft()
                        isPresenting = false
                    } label: {
                        Image.navIconDismiss
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                textEditorIsFocused = true
            }
            .onAppear {
                textEditorIsFocused = true
            }
            .onReceive(textEditorObserver.$throttledText) { _ in
                saveDraft()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didPublishPost)) { _ in
                clearDraft()
            }
            .task {
                if !draftLoaded {
                    loadDraft()
                    draftLoaded = true
                }
                if followings == nil {
                    loadFollowings()
                }
            }
        }
        .background(Color.navigationbarBg)
    }

    private func loadDraft() {
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            let draftStore = await buildDraftStore(from: bot)
            if let draft = await draftStore.loadDraft() {
                await MainActor.run {
                    textEditorObserver.text = draft.text
                    photos = draft.images
                }
                Log.info("Restored draft")
            }
        }
    }
    
    private func saveDraft() {
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            let draftStore = await buildDraftStore(from: bot)
            let currentText = await textEditorObserver.text
            let currentPhotos = await photos
            await draftStore.save(text: currentText, images: currentPhotos)
            Log.debug("Draft saved with \(currentText.count) characters and \(currentPhotos.count) photos.")
        }
    }

    private func clearDraft() {
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            let draftStore = await buildDraftStore(from: bot)
            await draftStore.clearDraft()
            Log.debug("Draft cleared")
        }
    }

    private func buildDraftStore(from bot: Bot) -> DraftStore {
        let currentIdentity = bot.identity ?? ""
        let draftKey = "com.planetary.ios.draft." + currentIdentity
        return DraftStore(draftKey: draftKey)
    }

    private func loadFollowings() {
        Task.detached {
            let bot = await botRepository.current
            guard let currentIdentity = bot.identity else {
                return
            }
            do {
                let result: [Identity] = try await bot.followings(identity: currentIdentity)
                await MainActor.run {
                    followings = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }
    }
}

@MainActor
fileprivate class TextEditorObserver: ObservableObject {
    @Published
    var throttledText = ""

    @Published
    var text = ""

    private var subscriptions = Set<AnyCancellable>()

    init() {
        $text
            .removeDuplicates()
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] value in
                self?.throttledText = value
            }
            .store(in: &subscriptions)
    }
}

struct ComposeView_Previews: PreviewProvider {
    @State
    static var isPresenting = false

    static var previews: some View {
        ComposeView(isPresenting: $isPresenting)
            .preferredColorScheme(.dark)
            .injectAppEnvironment(botRepository: .fake)
    }
}
