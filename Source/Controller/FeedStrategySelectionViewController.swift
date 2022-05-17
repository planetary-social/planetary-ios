//
//  FeedStrategySelectionViewController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 5/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit

class FeedStrategySelectionViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.FeedAlgorithm.feedAlgorithmTitle.text
        self.updateSettings()
    }

    override internal func updateSettings() {
        self.settings = [
            feedStrategy1Section(),
            feedStrategy2Section(),
            feedStrategy3Section()
        ]
        super.updateSettings()
    }
     
    private func selectedStrategy() -> FeedStrategy {
        if let data = UserDefaults.standard.object(forKey: "homeFeedStrategy") as? Data,
           let decodedObject = NSKeyedUnarchiver.unarchiveObject(with: data),
           let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        return PostsAndContactsAlgorithm()
    }

    private func feedStrategy1Section() -> Settings {
        let cell = DebugTableViewCellModel(
            title: "Posts and Contacts",
            valueClosure: { cell in
                if self.selectedStrategy() is PostsAndContactsAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [unowned self] _ in
                let encodedStrategy = try! NSKeyedArchiver.archivedData(withRootObject: PostsAndContactsAlgorithm(), requiringSecureCoding: false)
                UserDefaults.standard.set(encodedStrategy, forKey: "homeFeedStrategy")
                UserDefaults.standard.synchronize()
                updateSettings()
            }
        )
        
        return ("Feed Strategy 1", [cell], "Shows blah blah and foo")
    }
    
    private func feedStrategy2Section() -> Settings {
        let cell = DebugTableViewCellModel(
            title: "Posts Only",
            valueClosure: { cell in
                if let postsAlgorithm = self.selectedStrategy() as? PostsAlgorithm,
                   postsAlgorithm.onlyFollowed == true,
                   postsAlgorithm.wantPrivate == false {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [unowned self] _ in
                let encodedStrategy = try! NSKeyedArchiver.archivedData(withRootObject: PostsAlgorithm(wantPrivate: false, onlyFollowed: true), requiringSecureCoding: false)
                UserDefaults.standard.set(encodedStrategy, forKey: "homeFeedStrategy")
                UserDefaults.standard.synchronize()
                updateSettings()
            }
        )
        
        return ("Feed Strategy 1", [cell], "Shows blah blah and foo")
    }
    
    private func feedStrategy3Section() -> Settings {
        let cell = DebugTableViewCellModel(
            title: "Patchwork Algorithm",
            valueClosure: { cell in
                if let postsAlgorithm = self.selectedStrategy() as? PatchworkAlgorithm {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            },
            actionClosure: { [unowned self] _ in
                let encodedStrategy = try! NSKeyedArchiver.archivedData(withRootObject: PatchworkAlgorithm(), requiringSecureCoding: false)
                UserDefaults.standard.set(encodedStrategy, forKey: "homeFeedStrategy")
                UserDefaults.standard.synchronize()
                updateSettings()
            }
        )
        
        return ("Feed Strategy 3", [cell], "Shows blah blah and foo")
    }
}
