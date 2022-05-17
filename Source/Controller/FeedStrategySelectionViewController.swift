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
            recentlyActivePostsWithFollows()
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
        
        return (nil, [cell], Text.FeedAlgorithm.recentPostsWithFollowsAlgorithmDescription.text)
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
    
    // MARK: - Helpers
    
    private func selectedStrategy() -> FeedStrategy {
        if let data = UserDefaults.standard.object(forKey: UserDefaults.homeFeedStrategy) as? Data,
           let decodedObject = NSKeyedUnarchiver.unarchiveObject(with: data),
           let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return PostsAndContactsAlgorithm()
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
