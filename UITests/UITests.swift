//
//  UITests.swift
//  UITests
//
//  Created by Martin Dutra on 5/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import XCTest

class UITests: XCTestCase {
    
    // remove previous runs first
    // helps starting with a clean slate from failed runs
    override static func setUp() {
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        if appSupportDirs.count < 1 {
            XCTFail("no support dir")
            return
        }
        let repo = appSupportDirs[0]
            .appending("/FBTT")
            .appending("/"+NetworkKey.integrationTests.hexEncodedString())
        do {
            print("dropping \(repo)")
            try FileManager.default.removeItem(atPath: repo)
        } catch {
            print("failed to drop testdata repo, most likely first run")
        }
    }
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments = ["mock-phone-verification-api", "mock-push-api", "mock-directory-api", "mock-pub-api", "use-ci-network"]
        app.launch()

        let elementsQuery = app.scrollViews.otherElements
        elementsQuery.buttons["Let's get started"].tap()
        elementsQuery.buttons["That sounds great!"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "1989")

        elementsQuery.buttons["Next"].tap()

        app.typeText("Martin")
        elementsQuery.buttons["Next"].tap()
        
        // Skip directory step
        let button = app.buttons["Next"]
        let exists = NSPredicate(format: "exists == 1")
        expectation(for: exists, evaluatedWith: button, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        button.tap()
        
        
        // Skip photo step
        elementsQuery.buttons["I'll do it later"].tap()
        
        // Skip bio step
        elementsQuery.buttons["Skip"].tap()
        
        elementsQuery.buttons["Phew! I'm done!"].tap()

        let count = elementsQuery.tables["FeedTableView"].children(matching: .cell).count
        XCTAssert(count > 0)
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}
