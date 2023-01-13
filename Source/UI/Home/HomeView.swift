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
    init(helpDrawerState: HelpDrawerState, bot: Bot) {
        self.helpDrawerState = helpDrawerState
        self.dataSource = FeedStrategyMessageDataSource(
            strategy: HomeStrategy(),
            bot: bot
        )
    }

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource
    
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

    private var shouldShowFloatingButton: Bool {
        numberOfNewItems > 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            MessageList(dataSource: dataSource)
                .placeholder(when: dataSource.isEmpty) {
                    EmptyHomeView()
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
        .onReceive(NotificationCenter.default.publisher(for: .didChangeHomeFeedAlgorithm)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didPublishPost)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRefresh)) { _ in
            Task {
                await checkNewItemsIfNeeded()
            }
        }
        .onReceive(dataSource.$pages) { pages in
            if pages == 1 {
                updateBadgeNumber(value: 0)
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

    private func updateBadgeNumber(value: Int) {
        numberOfNewItems = 0
        lastTimeNewFeedUpdatesWasChecked = Date()
        let navigationController = appController.mainViewController?.homeFeatureViewController
        if value > 0 {
            navigationController?.tabBarItem.badgeValue = "\(value)"
        } else {
            navigationController?.tabBarItem.badgeValue = nil
        }
    }

    @MainActor
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
                HomeView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            NavigationView {
                HomeView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake)
    }
}
