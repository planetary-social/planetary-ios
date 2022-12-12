//
//  AnalyticsTests.swift
//
//
//  Created by Martin Dutra on 30/11/21.
//

import XCTest
@testable import Analytics

// swiftlint:disable implicitly_unwrapped_optional
final class AnalyticsTests: XCTestCase {

    private var service: AnalyticsServiceMock!
    private var analytics: Analytics!

    override func setUp() {
        super.setUp()
        service = AnalyticsServiceMock()
        analytics = Analytics(service: service)
    }

    func testIdentify() {
        analytics.identify(identifier: "identifier", name: nil, network: "network")
        XCTAssertTrue(service.identified)
    }

    func testForget() {
        analytics.forget()
        XCTAssertTrue(service.forgot)
    }

    func testIsEnabled() {
        XCTAssertTrue(analytics.isEnabled)
        service.isEnabled = false
        XCTAssertFalse(analytics.isEnabled)
    }

    func testOptIn() {
        analytics.optIn()
        XCTAssertTrue(service.optedIn)
        analytics.optOut()
        XCTAssertFalse(service.optedIn)
        analytics.optIn()
        XCTAssertTrue(service.optedIn)
    }

    // MARK: AppDelegate

    func testTrackTapAppNotification() {
        analytics.trackTapAppNotification()
        XCTAssertTrue(service.tracked)
    }

    func testTrackAppLaunch() {
        analytics.trackAppLaunch()
        XCTAssertTrue(service.tracked)
    }

    func testTrackAppForeground() {
        analytics.trackAppForeground()
        XCTAssertTrue(service.tracked)
    }

    func testTrackAppBackground() {
        analytics.trackAppBackground()
        XCTAssertTrue(service.tracked)
    }

    func testTrackAppExit() {
        analytics.trackAppExit()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidBackgroundTask() {
        analytics.trackDidStartBackgroundTask(taskIdentifier: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidReceiveRemoteNotification() {
        analytics.trackDidReceiveRemoteNotification()
        XCTAssertTrue(service.tracked)
    }

    // MARK: Bot

    func testTrackBodDidUpdateDatabase() {
        analytics.trackBotDidUpdateDatabase(count: 1, firstTimestamp: 2, lastTimestamp: 3, lastHash: "")
        XCTAssertTrue(service.tracked)
    }

    func testTrackBotDidRepair() {
        let repair = Analytics.BotRepair(function: #function, numberOfMessagesInDB: 2, numberOfMessagesInRepo: 1)
        analytics.trackBotDidRepair(databaseError: "", error: nil, repair: repair)
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidStartBeta1Migration() {
        analytics.trackDidStartBeta1Migration()
        XCTAssertTrue(service.tracked)
    }
    
    func testTrackDidDropDatabase() {
        analytics.trackDidDropDatabase()
        XCTAssertTrue(service.tracked)
    }
    
    func testTrackDidDismissBeta1Migration() {
        analytics.trackDidDismissBeta1Migration(syncedMessages: 0, totalMessages: 0)
        XCTAssertTrue(service.tracked)
    }

    // MARK: Conversions

    func testTrackDidUpdateProfile() {
        analytics.trackDidUpdateProfile()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidUpdateAvatar() {
        analytics.trackDidUpdateAvatar()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidFollowIdentity() {
        analytics.trackDidFollowIdentity()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidUnfollowIdentity() {
        analytics.trackDidUnfollowIdentity()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidBlockIdentity() {
        analytics.trackDidBlockIdentity()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidUnblockIdentity() {
        analytics.trackDidUnblockIdentity()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidPost() {
        analytics.trackDidPost()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidReply() {
        analytics.trackDidReply()
        XCTAssertTrue(service.tracked)
    }

    // MARK: Debug

    func testTrackDidShareLogs() {
        analytics.trackDidShareLogs()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidLogout() {
        analytics.trackDidLogout()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidLogoutAndOnboard() {
        analytics.trackDidLogoutAndOnboard()
        XCTAssertTrue(service.tracked)
    }

    // MARK: Offboarding

    func testTrackOffboardingStart() {
        analytics.trackOffboardingStart()
        XCTAssertTrue(service.tracked)
    }

    func testTrackOffboardingEnd() {
        analytics.trackOffboardingEnd()
        XCTAssertTrue(service.tracked)
    }

    // MARK: Onboarding

    func testTrackOnboarding() {
        analytics.trackOnboarding(.name)
        XCTAssertTrue(service.tracked)
    }

    func testTrackOnboardingComplete() {
        let data = Analytics.OnboardingStepData()
        analytics.trackOnboardingComplete(data)
        XCTAssertTrue(service.tracked)
    }

    func testTrackOnboardingStart() {
        analytics.trackOnboardingStart()
        XCTAssertTrue(service.tracked)
    }

    func testTrackOnboardingEnd() {
        analytics.trackOnboardingEnd()
        XCTAssertTrue(service.tracked)
    }

    // MARK: UI

    func testTrackDidTapTab() {
        analytics.trackDidTapTab(tabName: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidTapButton() {
        analytics.trackDidTapButton(buttonName: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidSelectAction() {
        analytics.trackDidSelectAction(actionName: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidTapSearchbar() {
        analytics.trackDidTapSearchbar(searchBarName: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidSelectItem() {
        analytics.trackDidSelectItem(kindName: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidSelectItemWithParams() {
        analytics.trackDidSelectItem(kindName: "test", param: "param", value: "value")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidShowScreen() {
        analytics.trackDidShowScreen(screenName: "test")
        XCTAssertTrue(service.tracked)
    }

    // MARK: Repair

    func testTrackDidRepair() {
        analytics.trackDidRepair(function: "myfunction")
        XCTAssertTrue(service.tracked)
    }

    // MARK: Statistics

    func testTrackStatistics() {
        let now = Date.init(timeIntervalSinceNow: 0)
        var statistics = Analytics.Statistics(lastSyncDate: now, lastRefreshDate: now)
        statistics.database = Analytics.DatabaseStatistics(lastReceivedMessage: 1, messageCount: 1)
        statistics.repo = Analytics.RepoStatistics(
            feedCount: 1,
            messageCount: 2,
            numberOfPublishedMessages: 3,
            lastHash: ""
        )
        statistics.peer = Analytics.PeerStatistics(peers: 1, connectedPeers: 2)
        analytics.trackStatistics(statistics)
        XCTAssertTrue(service.tracked)
    }
}
