//
//  BotViewController.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BotViewController: DebugTableViewController {

    var bot: Bot
    let configuration: AppConfiguration?
    var statistics: BotStatistics = MutableBotStatistics()

    // MARK: Lifecycle

    init(bot: Bot, configuration: AppConfiguration? = nil) {
        self.bot = bot
        self.configuration = configuration
        super.init(style: .grouped)
        self.navigationItem.title = bot.name
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateStatistics()
    }

    internal override func updateSettings() {
        self.settings = [self.info(), self.operations(), self.peers(), self.repo()]
        super.updateSettings()
    }

    private func updateStatistics() {
        let operation = StatisticsOperation()
        operation.completionBlock = { [weak self] in
            switch operation.result {
            case .success(let statistics):
                self?.statistics = statistics
                DispatchQueue.main.async { [weak self] in
                    self?.updateSettings()
                }
            case .failure(let error):
                Log.optional(error)
            }
        }
        let operationQueue = OperationQueue()
        operationQueue.addOperation(operation)
    }

    private func info() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Version",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.detailTextLabel?.text = self.bot.version
            },
                                             actionClosure: nil)]

        if self.bot.isGoBot {
            settings += [DebugTableViewCellModel(title: "Details",
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure:
                {
                    cell in
                    cell.accessoryType = .disclosureIndicator
                },
                                                 actionClosure:
                {
                    [unowned self] cell in
                    let controller = GoBotViewController()
                    self.navigationController?.pushViewController(controller, animated: true)
                }
            )]
        }

        return ("Info", settings, nil)
    }

    private func operations() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Sync",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                if self.bot.isSyncing { cell.showActivityIndicator() }
                else { cell.detailTextLabel?.text = self.statistics.lastSyncText }
            },
                                             actionClosure:
            {
                [unowned self] cell in
                cell.showActivityIndicator()
                let sendMissionOperation = SendMissionOperation(quality: .high)
                sendMissionOperation.completionBlock = { [weak self] in
                    DispatchQueue.main.async { [weak self] in
                        cell.hideActivityIndicator()
                        self?.updateSettings()
                    }
                }
                let operationQueue = OperationQueue()
                operationQueue.addOperation(sendMissionOperation)
            })]

        settings += [DebugTableViewCellModel(title: "Refresh",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                if self.bot.isRefreshing { cell.showActivityIndicator() }
                else { cell.detailTextLabel?.text = self.statistics.lastRefreshText }
            },
                                             actionClosure:
            {
                [unowned self] cell in
                cell.showActivityIndicator()
                self.bot.refresh(load: .long, queue: .main) {
                    [weak self] _, _ in
                    cell.hideActivityIndicator()
                    self?.updateSettings()
                }
            })]

        return ("Operations", settings, nil)
    }

    private func repo() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []
        let statistics = self.statistics

        settings += [DebugTableViewCellModel(title: "Feeds",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = "\(statistics.repo.feedCount)"
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Messages",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = "\(statistics.repo.messageCount)"
            },
                                             actionClosure: nil)]
        
        settings += [DebugTableViewCellModel(title: "Published Messages",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure:
        {
            cell in
            cell.detailTextLabel?.text = "\(statistics.repo.numberOfPublishedMessages)"
        },
                                         actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Last received message",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = "\(statistics.db.lastReceivedMessage)"
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Path",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = statistics.repo.path
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = true
                cell.detailTextLabel?.lineBreakMode = .byTruncatingHead
            },
                                             actionClosure: nil)]

        return ("Repo", settings, nil)
    }

    private func peers() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Connections (open/total)",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = "\(self.statistics.peer.connectionCount) / \(self.statistics.peer.count)"
            },
                                             actionClosure: nil)]

        for (address, identity) in self.statistics.peer.identities {
            settings += [DebugTableViewCellModel(title: address,
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = identity
                },
                                                 actionClosure: nil)]
        }

        return ("Peers", settings, nil)
    }
}

fileprivate extension Bot {

    var isGoBot: Bool {
        return self.name == "GoBot"
    }

    var isFakeBot: Bool {
        return self.name == "FakeBot"
    }
}

fileprivate extension BotStatistics {

    var lastSyncText: String {
        return self.format(date: self.lastSyncDate, duration: self.lastSyncDuration)
    }

    var lastRefreshText: String {
        return self.format(date: self.lastRefreshDate, duration: self.lastRefreshDuration)
    }

    private func format(date: Date?, duration: TimeInterval) -> String {
        guard let date = date else { return "" }
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        let timeString = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        var string = String(format: "%.1f", duration)
        string = "\(string)s on \(dateString) @ \(timeString)"
        return string
    }
}
