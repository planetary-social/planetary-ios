//
//  DiscoveryFeedStrategySelectionViewController.swift
//  Planetary
//
//  Created by Rabble on 8/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import SafariServices

/// Allows the user to choose the algorithm used to fetch the Discover Feed.
class DiscoveryFeedStrategySelectionViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Localized.DiscoveryFeedAlgorithm.feedAlgorithmTitle.text
        self.updateSettings()
    }

    override internal func updateSettings() {
        self.settings = [
            recentPosts(),
            randomPosts(),
            viewSource()
        ]
        super.updateSettings()
    }

    private func recentPosts() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Localized.DiscoveryFeedAlgorithm.recentPostsAlgorithm.text,
            valueClosure: { cell in
                if let postsAlgorithm = self.selectedStrategy() as? PostsAlgorithm,
                    postsAlgorithm.onlyFollowed == false,
                    postsAlgorithm.wantPrivate == false {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: PostsAlgorithm(wantPrivate: false, onlyFollowed: false))
            }
        )
        
        return (nil, [cell], Localized.DiscoveryFeedAlgorithm.recentPostsAlgorithmDescription.text)
    }

    private func randomPosts() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Localized.DiscoveryFeedAlgorithm.randomPostsAlgorithm.text,
            valueClosure: { cell in
                if self.selectedStrategy() is RandomAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: RandomAlgorithm(onlyFollowed: false))
            }
        )
        
        return (nil, [cell], Localized.DiscoveryFeedAlgorithm.randomPostsAlgorithmDescription.text)
    }
    
    private func viewSource() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Localized.FeedAlgorithm.viewAlgorithmSource.text,
            valueClosure: { cell in
                cell.textLabel?.textColor = .systemBlue
            },
            actionClosure: { [weak self] _ in
                // swiftlint:disable line_length
                guard let url = URL(string: "https://github.com/planetary-social/planetary-ios/tree/main/Source/GoBot/FeedStrategy") else {
                    return
                }
                // swiftlint:enable line_length
                let controller = SFSafariViewController(url: url)
                self?.present(controller, animated: true, completion: nil)
            }
        )
        
        return (Localized.FeedAlgorithm.sourceCode.text, [cell], Localized.FeedAlgorithm.sourceCodeDescription.text)
    }
    
    // MARK: - Helpers
    
    private func selectedStrategy() -> FeedStrategy {
        if let data = UserDefaults.standard.object(forKey: UserDefaults.discoveryFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return RandomAlgorithm(onlyFollowed: false)
    }
    
    private func save(strategy: FeedStrategy) {
        do {
            let encodedStrategy = try NSKeyedArchiver.archivedData(
                withRootObject: strategy,
                requiringSecureCoding: false
            )
            UserDefaults.standard.set(encodedStrategy, forKey: UserDefaults.discoveryFeedStrategy)
            UserDefaults.standard.synchronize()
            updateSettings()
            NotificationCenter.default.post(name: .didChangeDiscoverFeedAlgorithm, object: nil)
            Analytics.shared.trackBotDidChangeDiscoveryFeedStrategy(to: String(describing: type(of: strategy)))
        } catch {
            Log.optional(error)
        }
    }
}
