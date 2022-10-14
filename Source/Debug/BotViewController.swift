//
//  BotViewController.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class BotViewController: DebugTableViewController {

    var bot: Bot
    let configuration: AppConfiguration?
    var statistics = BotStatistics()

    // MARK: Lifecycle

    init(bot: Bot, configuration: AppConfiguration? = nil) {
        self.bot = bot
        self.configuration = configuration
        super.init(style: .insetGrouped)
        self.navigationItem.title = bot.name
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateStatistics()
    }

    override internal func updateSettings() {
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
                                             valueClosure: {
                [unowned self] cell in
                cell.detailTextLabel?.text = self.bot.version
            },
                                             actionClosure: nil)]

        if self.bot.isGoBot {
            settings += [DebugTableViewCellModel(title: "Details",
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure: {
                    cell in
                    cell.accessoryType = .disclosureIndicator
                },
                                                 actionClosure: {
                    [unowned self] _ in
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
                                             valueClosure: {
                cell in
                if self.bot.isSyncing { cell.showActivityIndicator() } else { cell.detailTextLabel?.text = self.statistics.lastSyncText }
            },
                                             actionClosure: {
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
                                             valueClosure: {
                cell in
                if self.bot.isRefreshing { cell.showActivityIndicator() } else { cell.detailTextLabel?.text = self.statistics.lastRefreshText }
            },
                                             actionClosure: {
                [unowned self] cell in
                cell.showActivityIndicator()
                self.bot.refresh(load: .long, queue: .main) { [weak self] _, _ in
                    cell.hideActivityIndicator()
                    self?.updateSettings()
                }
            })]
        
        settings += [
            DebugTableViewCellModel(
                title: "Delete View Database",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.textLabel?.textColor = .systemRed
                },
                actionClosure: { [unowned self] cell in
                    self.confirm(
                        message: "This will delete the SQL database. It will be several minutes before you see posts" +
                            "again. Are you sure?"
                    ) {
                        AppController.shared.showProgress()
                        Task {
                            do {
                                try await self.bot.dropViewDatabase()
                                self.alert(
                                    message: "View Database deleted successfully. It will take some time before you" +
                                        "see posts again.",
                                    cancelTitle: "Ok"
                                )
                            } catch {
                                self.alert(error: error)
                                
                            }
                            AppController.shared.hideProgress()
                        }
                    }
                }
            )
        ]

        return ("Operations", settings, nil)
    }

    private func repo() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []
        let statistics = self.statistics

        settings += [DebugTableViewCellModel(title: "Feeds",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(statistics.repo.feedCount)"
            },
                                             actionClosure: nil)]

        settings += [
            DebugTableViewCellModel(
                title: "Messages in Badger",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.detailTextLabel?.text = String(statistics.repo.messageCount)
                }
            )
        ]
        
        settings += [
            DebugTableViewCellModel(
                title: "Messages in SQLite",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.detailTextLabel?.text = String(statistics.db.messageCount)
                }
            )
        ]
        
        settings += [DebugTableViewCellModel(title: "Published Messages",
                                         cellReuseIdentifier: DebugValueTableViewCell.className,
                                         valueClosure: {
            cell in
            cell.detailTextLabel?.text = "\(statistics.repo.numberOfPublishedMessages)"
        },
                                         actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Last received message",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(statistics.db.lastReceivedMessage)"
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Path",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = statistics.repo.path
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = true
                cell.detailTextLabel?.lineBreakMode = .byTruncatingHead
            },
                                             actionClosure: nil)]

        return ("Repo", settings, nil)
    }
    
    var connectToPeerCell: DebugTextFieldTableViewCell?

    private func peers() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []
        
        settings += [DebugTableViewCellModel(title: "Connect to peer:",
                                             cellReuseIdentifier: DebugTextFieldTableViewCell.className,
                                             valueClosure: { [weak self] cell in
            guard let cell = cell as? DebugTextFieldTableViewCell else {
                return
            }
            
            self?.connectToPeerCell = cell
        })]
        
        settings += [DebugTableViewCellModel(title: "Connect",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             actionClosure: { [weak self] cell in
            guard let enteredString = self?.connectToPeerCell?.textField.text,
                let multiserver = MultiserverAddress(string: enteredString) else {
                Log.error("Could not parse peer address")
                return
            }
            
            Bots.current.sync(peers: [multiserver]) { error, _, _ in
                Log.optional(error)
            }
        })]

        settings += [DebugTableViewCellModel(title: "Connections (open/total)",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = "\(self.statistics.peer.connectionCount) / \(self.statistics.peer.count)"
            },
                                             actionClosure: nil)]

        for (address, identity) in self.statistics.peer.identities {
            settings += [DebugTableViewCellModel(title: address,
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure: {
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
        self.name == "GoBot"
    }

    var isFakeBot: Bool {
        self.name == "FakeBot"
    }
}

fileprivate extension BotStatistics {

    var lastSyncText: String {
        self.format(date: self.lastSyncDate, duration: self.lastSyncDuration)
    }

    var lastRefreshText: String {
        self.format(date: self.lastRefreshDate, duration: self.lastRefreshDuration)
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
