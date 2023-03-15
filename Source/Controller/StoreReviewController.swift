//
//  StoreReviewController.swift
//  Planetary
//
//  Created by Samuel Kubinsky on 30/10/2022.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import StoreKit
import Logger
import CrashReporting

/// SKStoreReviewController facade which masks suitability checks to show App Store review prompt.
enum StoreReviewController {
    
    private typealias YearlyPrompts = [String: Int]
    
    enum PromptError: Error {
        case cannotReviewWhileLoggedOut
        case noActiveSceneToPresentTo
    }
    
    // MARK: Settings
    
    private static let maxPromptsPerYear = 1
    
    private static let messageThreshold = 100
    
    // MARK: Yearly prompt count storage
    
    private static let userDefaultsKey = UserDefaults.appStoreReviewPromptCount
    
    private static var yearlyPrompts: YearlyPrompts? {
        get {
            UserDefaults.standard.object(forKey: userDefaultsKey) as? YearlyPrompts
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: userDefaultsKey)
        }
    }
    
    private static var thisYearKey: String {
        let yearFormatStyle = Date.FormatStyle().year()
        return Date().formatted(yearFormatStyle)
    }
    
    private static var isYearlyPromptCountExceeded: Bool {
        guard let promptsThisYear = yearlyPrompts?[thisYearKey] else {
            return false
        }
        
        return promptsThisYear >= maxPromptsPerYear
    }
    
    private static func incrementYearlyPromptCount() {
        var dictionary = yearlyPrompts ?? YearlyPrompts()
        let currentCount = dictionary[thisYearKey] ?? 0
        dictionary[thisYearKey] = currentCount + 1
        yearlyPrompts = dictionary
    }
    
    // MARK: Prompt
    
    static func promptIfConditionsMet() throws {
        guard let identity = Bots.current.identity else {
            throw PromptError.cannotReviewWhileLoggedOut
        }

        guard !isYearlyPromptCountExceeded else {
            return
        }
        
        checkFeed(identity: identity)
    }
    
    /// Checks user's feed whether they posted enough messages, if yes present App Store review prompt.
    private static func checkFeed(identity: Identity) {
        Bots.current.feed(identity: identity) { messages, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            guard error == nil, messages.count >= messageThreshold else {
                return
            }
            
            do {
                try presentAppStoreReviewPrompt()
                incrementYearlyPromptCount()
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }
    }
    
    private static func presentAppStoreReviewPrompt() throws {
        let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene
        
        guard let scene = scene else {
            throw PromptError.noActiveSceneToPresentTo
        }
        
        SKStoreReviewController.requestReview(in: scene)
    }
}
