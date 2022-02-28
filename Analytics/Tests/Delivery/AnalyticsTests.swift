//
//  AnalyticsTests.swift
//
//
//  Created by Martin Dutra on 30/11/21.
//

import XCTest
@testable import Analytics

final class AnalyticsTests: XCTestCase {

    private var service: AnalyticsServiceMock!
    private var analytics: Analytics!

    override func setUp() {
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

    func testTrackDidBackgroundFetch() {
        analytics.trackDidBackgroundFetch()
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidBackgroundTask(taskIdentifier: String) {
        analytics.trackDidBackgroundTask(taskIdentifier: "test")
        XCTAssertTrue(service.tracked)
    }

    func testTrackDidReceiveRemoteNotification() {
        analytics.trackDidReceiveRemoteNotification()
        XCTAssertTrue(service.tracked)
    }

    // MARK: Bot

    func testTrackBotDidUpdateMessages() {
        analytics.trackBotDidUpdateMessages(count: 2)
        XCTAssertTrue(service.tracked)
    }

    func testTrackBotDidSync() {
        analytics.trackBotDidSkipMessage(key: "noop", reason: "unknown")
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

    func testTrackDidShowScreen() {
        analytics.trackDidShowScreen(screenName: "test")
        XCTAssertTrue(service.tracked)
    }

}
