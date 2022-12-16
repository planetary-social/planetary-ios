//
//  HomeView.swift
//  Planetary
//
//  Created by Martin Dutra on 27/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct HomeView: View, HelpDrawerHost {
    init(helpDrawerState: HelpDrawerState) {
        self.helpDrawerState = helpDrawerState
    }

    @ObservedObject
    private var helpDrawerState: HelpDrawerState

    private var feedStrategyStore = FeedStrategyStore()

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    let helpDrawerType = HelpDrawer.home

    func dismissDrawer(completion: (() -> Void)?) {
        helpDrawerState.isShowingHomeHelpDrawer = false
        // Unfortunately, there is no good way to know when the popover dismissed in SwiftUI
        // So here I use a nasty simple trick to let the completion open the next drawer.
        // Fortunately, we can get rid of this after we migrate the remaining screens to SwiftUI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            completion?()
        }
    }

    @SwiftUI.Environment(\.horizontalSizeClass)
    var horizontalSizeClass

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
                                    EmptyHomeView()
                                } else {
                                    ForEach(messages) { message in
                                        Button {
                                            if let contact = message.content.contact {
                                                appController.open(identity: contact.contact)
                                            } else {
                                                appController.open(identifier: message.id)
                                            }
                                        } label: {
                                            MessageView(message: message)
                                                .onAppear {
                                                    if message == messages.last {
                                                        loadMore()
                                                    }
                                                }
                                        }
                                        .buttonStyle(MessageButtonStyle())
                                    }
                                }
                            }
                            .frame(maxWidth: 500)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
                            if isLoadingMoreMessages, !noMoreMessages {
                                HStack {
                                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    LoadingView()
                }
            }
            if shouldShowFloatingButton {
                FloatingButton(count: numberOfNewItems, isLoading: isLoadingFromScratch)
            }
        }
        .background(Color.appBg)
        .navigationTitle(Localized.home.text)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    helpDrawerState.isShowingHomeHelpDrawer = true
                } label: {
                    Image.navIconHelp
                }
                .popover(isPresented: $helpDrawerState.isShowingHomeHelpDrawer) {
                    Group {
                        if #available(iOS 16.0, *) {
                            HelpDrawerCoordinator.helpDrawerView(for: self) {
                                helpDrawerState.isShowingHomeHelpDrawer = false
                            }
                            .presentationDetents([.medium])
                        } else {
                            HelpDrawerCoordinator.helpDrawerView(for: self) {
                                helpDrawerState.isShowingHomeHelpDrawer = false
                            }
                        }
                    }
                    .onAppear {
                        Analytics.shared.trackDidShowScreen(screenName: helpDrawerType.screenName)
                        HelpDrawerCoordinator.didShowHelp(for: helpDrawerType)
                    }
                }
                Button {
                    Analytics.shared.trackDidTapButton(buttonName: "compose")
                    showCompose()
                } label: {
                    Image.navIconWrite
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
            if messages == nil {
                await loadFromScratch()
            }
        }
        .refreshable {
            await loadFromScratch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didChangeHomeFeedAlgorithm)) { _ in
            Task.detached {
                await loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { _ in
            Task.detached {
                await loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didPublishPost)) { _ in
            Task.detached {
                await loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRefresh)) { _ in
            Task.detached {
                await checkNewItemsIfNeeded()
            }
        }
        .onAppear {
            CrashReporting.shared.record("Did Show Home")
            Analytics.shared.trackDidShowScreen(screenName: "home")
            HelpDrawerCoordinator.showFirstTimeHelp(for: helpDrawerType, state: helpDrawerState)
        }
    }

    private func showCompose() {
        let controller = NewPostViewController()
        controller.didPublish = { post in
            NotificationCenter.default.post(.didPublishPost(post))
        }
        let navController = UINavigationController(rootViewController: controller)
        appController.present(navController, animated: true)
    }

    func loadFromScratch() async {
        guard !isLoadingFromScratch else {
            return
        }
        isLoadingFromScratch = true
        let strategy = feedStrategyStore.homeFeedStrategy
        let bot = botRepository.current
        let pageSize = 50
        do {
            let newMessages = try await bot.feed(strategy: strategy, limit: pageSize, offset: 0)
            await MainActor.run {
                messages = newMessages
                offset = newMessages.count
                noMoreMessages = newMessages.count < pageSize
                isLoadingFromScratch = false
                numberOfNewItems = 0
                updateBadgeNumber(value: 0)
            }
        } catch {
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.shared.optional(error)
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoadingFromScratch = false
                messages = []
                offset = 0
                noMoreMessages = true
                numberOfNewItems = 0
                updateBadgeNumber(value: 0)
            }
        }
    }

    func loadMore() {
        guard !isLoadingMoreMessages, !noMoreMessages else {
            return
        }
        isLoadingMoreMessages = true
        Task.detached {
            let strategy = await feedStrategyStore.homeFeedStrategy
            let bot = await botRepository.current
            let pageSize = 50
            do {
                let newMessages = try await bot.feed(strategy: strategy, limit: pageSize, offset: offset)
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
        let navigationController = appController.mainViewController?.homeFeatureViewController
        if value > 0 {
            navigationController?.tabBarItem.badgeValue = "\(value)"
        } else {
            navigationController?.tabBarItem.badgeValue = nil
        }
    }

    private func checkNewItemsIfNeeded() async {
        // Check that more than a minute passed since the last time we checked for new updates
        let elapsed = Date().timeIntervalSince(lastTimeNewFeedUpdatesWasChecked)
        guard elapsed > 60 else {
            return
        }
        let bot = botRepository.current
        if let lastMessage = messages?.first?.key {
            do {
                let result = try await bot.numberOfRecentItems(since: lastMessage)
                await MainActor.run {
                    lastTimeNewFeedUpdatesWasChecked = Date()
                    numberOfNewItems = result
                    updateBadgeNumber(value: result)
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
            }
        }
    }
}

struct FeedStrategyStore {
    var homeFeedStrategy: FeedStrategy {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.object(forKey: UserDefaults.homeFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return RecentlyActivePostsAndContactsAlgorithm()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                HomeView(helpDrawerState: HelpDrawerState())
            }
            NavigationView {
                HomeView(helpDrawerState: HelpDrawerState())
            }
            .preferredColorScheme(.dark)
        }
        .environmentObject(BotRepository.fake)
        .environmentObject(AppController.shared)
    }
}
