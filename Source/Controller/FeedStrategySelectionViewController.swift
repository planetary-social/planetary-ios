//
//  FeedStrategySelectionViewController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 5/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import SafariServices

/// Allows the user to choose the algorithm used to fetch the Home Feed.
class FeedStrategySelectionViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.FeedAlgorithm.feedAlgorithmTitle.text
        self.updateSettings()
    }

    override internal func updateSettings() {
        self.settings = [
            recentPostsWithFollows(),
            recentPosts(),
            recentlyActivePostsWithFollows(),
            randomPosts(),
            viewSource()
        ]
        super.updateSettings()
    }

    private func recentPostsWithFollows() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Text.FeedAlgorithm.recentPostsWithFollowsAlgorithm.text,
            valueClosure: { cell in
                if self.selectedStrategy() is PostsAndContactsAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: PostsAndContactsAlgorithm())
            }
        )
        
        return (
            Text.FeedAlgorithm.algorithms.text,
            [cell],
            Text.FeedAlgorithm.recentPostsWithFollowsAlgorithmDescription.text
        )
    }
    
    private func recentPosts() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Text.FeedAlgorithm.recentPostsAlgorithm.text,
            valueClosure: { cell in
                if let postsAlgorithm = self.selectedStrategy() as? PostsAlgorithm,
                    postsAlgorithm.onlyFollowed == true,
                    postsAlgorithm.wantPrivate == false {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: PostsAlgorithm(wantPrivate: false, onlyFollowed: true))
            }
        )
        
        return (nil, [cell], Text.FeedAlgorithm.recentPostsAlgorithmDescription.text)
    }
    
    private func recentlyActivePostsWithFollows() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Text.FeedAlgorithm.recentlyActivePostsWithFollowsAlgorithm.text,
            valueClosure: { cell in
                if self.selectedStrategy() is RecentlyActivePostsAndContactsAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: RecentlyActivePostsAndContactsAlgorithm())
            }
        )
        
        return (nil, [cell], Text.FeedAlgorithm.recentlyActivePostsWithFollowsAlgorithmDescription.text)
    }
    
    private func randomPosts() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Text.DiscoveryFeedAlgorithm.randomPostsAlgorithm.text,
            valueClosure: { cell in
                if self.selectedStrategy() is RandomAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [weak self] _ in
                self?.save(strategy: RandomAlgorithm(onlyFollowed: true))
            }
        )
        
        return (nil, [cell], Text.DiscoveryFeedAlgorithm.randomPostsAlgorithmDescription.text)
    }
    
    private func viewSource() -> Settings {
        let cell = DebugTableViewCellModel(
            title: Text.FeedAlgorithm.viewAlgorithmSource.text,
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
        
        return (Text.FeedAlgorithm.sourceCode.text, [cell], Text.FeedAlgorithm.sourceCodeDescription.text)
    }
    
    // MARK: - Helpers
    
    private func selectedStrategy() -> FeedStrategy {
        if let data = UserDefaults.standard.object(forKey: UserDefaults.homeFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return RecentlyActivePostsAndContactsAlgorithm()
    }
    
    private func save(strategy: FeedStrategy) {
        do {
            let encodedStrategy = try NSKeyedArchiver.archivedData(
                withRootObject: strategy,
                requiringSecureCoding: false
            )
            UserDefaults.standard.set(encodedStrategy, forKey: UserDefaults.homeFeedStrategy)
            UserDefaults.standard.synchronize()
            updateSettings()
            NotificationCenter.default.post(name: .didChangeHomeFeedAlgorithm, object: nil)
            Analytics.shared.trackBotDidChangeHomeFeedStrategy(to: String(describing: type(of: strategy)))
        } catch {
            Log.optional(error)
        }
    }
}
