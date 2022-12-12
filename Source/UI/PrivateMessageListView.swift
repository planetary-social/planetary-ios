//
//  PrivateMessageListView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 12/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Logger
import CrashReporting
import Analytics

struct PrivateMessageListView: View {
    
    @EnvironmentObject
    private var botRepository: BotRepository
    
    @State
    private var messages: [Message]?
    
    @State
    private var isLoadingFromScratch = false
    
    @State
    private var isLoadingMoreMessages = false
    
    @State
    private var offset = 0
    
    @State
    private var noMoreMessages = false
    
    @State
    private var numberOfNewItems = 0
    
    @State
    private var lastTimeNewFeedUpdatesWasChecked = Date()
    
    @State
    private var errorMessage: String?
    
    private var shouldShowAlert: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { _ in
            errorMessage = nil
        }
    }
    
    private var shouldShowFloatingButton: Bool {
        numberOfNewItems > 0
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let messages = messages {
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack {
                            LazyVStack(alignment: .center) {
                                if messages.isEmpty {
                                    Text("No messages")
                                } else {
                                    ForEach(messages) { message in
                                        Button {
                                            if let contact = message.content.contact {
                                                AppController.shared.open(identity: contact.contact)
                                            } else {
                                                AppController.shared.open(identifier: message.id)
                                            }
                                        } label: {
                                            MessageView(message: message)
                                                .onAppear {
                                                    if message == messages.last {
                                                        loadMore()
                                                    }
                                                }
                                        }
//                                        .buttonStyle(MessageButtonStyle())
                                    }
                                }
                            }
                            .frame(maxWidth: 500)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
                            if noMoreMessages {
                                Text("No more messages")
                            }
                            if isLoadingMoreMessages, !noMoreMessages {
                                HStack {
                                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Text("Loading") // LoadingView()
                }
            }
        }
        .alert(
            Localized.error.text,
            isPresented: shouldShowAlert,
            actions: {
                Button(Localized.tryAgain.text) {
                    Task {
                        await loadFromScratch()
                    }
                }
                Button(Localized.cancel.text, role: .cancel) {
                    shouldShowAlert.wrappedValue = false
                }
            },
            message: {
                Text(errorMessage ?? "")
            }
        )
        .task {
            await loadFromScratch()
        }
        .refreshable {
            await loadFromScratch()
        }
        .environmentObject(botRepository)
        .navigationTitle(Localized.home.text)
        .background(Color.appBg)
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { _ in
            Task.detached {
                await loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRefresh)) { _ in
            Task.detached {
                await checkNewItemsIfNeeded()
            }
        }
    }
    
    private func showCompose() {
    }
    
    func loadFromScratch() async {
        loadMore()
    }
    
    func loadMore() {
        guard !isLoadingMoreMessages, !noMoreMessages else {
            return
        }
        isLoadingMoreMessages = true
        let pageSize = 100
        Task.detached {
            do {
                let newMessages = try await  botRepository.current.privateMessagesFeed(limit: pageSize, offset: offset)
                await MainActor.run {
                    messages?.append(contentsOf: newMessages)
                    offset += newMessages.count
                    noMoreMessages = newMessages.count < pageSize
                    isLoadingMoreMessages = false
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    isLoadingMoreMessages = false
                }
            }
        }
    }
    
    private func updateBadgeNumber(value: Int) {
        let navigationController = AppController.shared.mainViewController?.homeFeatureViewController
        if value > 0 {
            navigationController?.tabBarItem.badgeValue = "\(value)"
        } else {
            navigationController?.tabBarItem.badgeValue = nil
        }
    }
    
    private func checkNewItemsIfNeeded() async {
    }
}

struct PrivateMessageListView_Previews: PreviewProvider {
    static var previews: some View {
        PrivateMessageListView()
            .environmentObject(BotRepository.fake)
    }
}
