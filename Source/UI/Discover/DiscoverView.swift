//
//  DiscoverView.swift
//  Planetary
//
//  Created by Martin Dutra on 27/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct DiscoverView: View, HelpDrawerHost {
    init(helpDrawerState: HelpDrawerState, bot: Bot) {
        self.helpDrawerState = helpDrawerState
        self.dataSource = FeedStrategyMessageDataSource(
            strategy: DiscoverStrategy(),
            bot: bot
        )
    }

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    @ObservedObject
    private var helpDrawerState: HelpDrawerState

    private var feedStrategyStore = DiscoverFeedStrategyStore()

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    let helpDrawerType = HelpDrawer.discover

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

    var body: some View {
        ZStack(alignment: .top) {
            MessageGrid(dataSource: dataSource)
                .placeholder(when: dataSource.isEmpty) {
                    EmptyHomeView()
                }
        }
        .background(Color.appBg)
        .navigationTitle(Localized.explore.text)
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
        .onReceive(NotificationCenter.default.publisher(for: .didChangeDiscoverFeedAlgorithm)) { _ in
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
        .onAppear {
            CrashReporting.shared.record("Did Show Discover")
            Analytics.shared.trackDidShowScreen(screenName: "discover")
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
}

struct DiscoverFeedStrategyStore {
    var discoverFeedStrategy: FeedStrategy {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.object(forKey: UserDefaults.discoveryFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return RandomAlgorithm(onlyFollowed: false)
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                DiscoverView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            NavigationView {
                DiscoverView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake)
    }
}
