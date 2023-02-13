//
//  GoBotViewController.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class GoBotViewController: DebugTableViewController {
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "GoBot: \(GoBot.shared.version)"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if !GoBot.shared.bot.isRunning {
            self.settings = [self.actions()]
            self.tableView.reloadData()
            return
        }
    }
    
    override internal func updateSettings() {
        self.settings = [
            self.status(),
            self.actions(),
            self.viewDB(),
            self.repoInfo()
        ]
        super.updateSettings()
    }
    
    @objc func runningToggleDidChange(toggle: UISwitch) {
        if GoBot.shared.bot.isRunning {
            _ = GoBot.shared.bot.logout()
        } else {
            Log.unexpected(.apiError, "TODO: just trigger logout")
        }
    }

    // MARK: - Sections

    // MARK: Status

    private var versionCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Version",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.detailTextLabel?.text = GoBot.shared.version
            },
            actionClosure: nil
        )
    }

    private var runningCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Running",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                let toggle = UISwitch()
                toggle.isOn = GoBot.shared.bot.isRunning
                toggle.addTarget(self, action: #selector(self.runningToggleDidChange), for: .valueChanged)
                cell.accessoryView = toggle
            },
            actionClosure: nil
        )
    }

    private var connectionsCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "#Connections",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.detailTextLabel?.text = String(GoBot.shared.bot.openConnections())
            },
            actionClosure: nil
        )
    }

    private var disconnectAllCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Disconnect all",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.accessoryType = .detailButton
            },
            actionClosure: { _ in
                DispatchQueue.global(qos: .utility).async {
                    GoBot.shared.bot.disconnectAll()
                }
            }
        )
    }

    private func status() -> DebugTableViewController.Settings {
        var settings = [versionCell, runningCell]
        if GoBot.shared.bot.openConnections() > 0 {
            settings += [connectionsCell, disconnectAllCell]
        }
        return ("Status", settings, nil)
    }

    // MARK: Actions

    private var publishCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Publish",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.accessoryType = .detailButton
            },
            actionClosure: { _ in
                let publishCtrl = SimplePublishViewController()
                self.navigationController?.pushViewController(publishCtrl, animated: true)
            }
        )
    }

    private var fullFsckAndRepairCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Full FSCK and Repair",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.detailTextLabel?.text = "Run"
            },
            actionClosure: { _ in
                DispatchQueue.global(qos: .background).async {
                    let (worked, _) = GoBot.shared.bot.fsckAndRepair()
                    guard worked else {
                        Log.unexpected(.botError, "manual fsck failed")
                        return
                    }
                }
            }
        )
    }

    private func purgeRepoAndView() {
        let searchPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard let appSupportDir = searchPaths.first else {
            Log.unexpected(.apiError, "purge error, no search paths found")
            updateSettings()
            return
        }
        guard let network = AppConfiguration.current?.network else {
            Log.unexpected(.apiError, "purge error, no network found")
            updateSettings()
            return
        }
        Task {
            do {
                if GoBot.shared.bot.isRunning {
                    GoBot.shared.bot.logout()
                }
                await GoBot.shared.database.close()
                let path = appSupportDir.appending("/FBTT/").appending(network.hexEncodedString())
                try FileManager.default.removeItem(atPath: path)
                Log.info("repo deleted.. should stop and restart sbot")
            } catch {
                Log.unexpected(.apiError, "purge error")
                Log.optional(error)
            }
            updateSettings()
        }
    }

    private func purgeJustViewDB() {
        Task {
            do {
                if GoBot.shared.bot.isRunning {
                    GoBot.shared.bot.logout()
                }
                if let dbPath = GoBot.shared.database.currentPath {
                    await GoBot.shared.database.close()
                    try FileManager.default.removeItem(atPath: dbPath)
                } else {
                    throw ViewDatabaseError.notOpen
                }
            } catch {
                Log.unexpected(.apiError, "purge error")
                Log.optional(error)
            }
            updateSettings()
        }
    }
    
    private var deleteRepoCell: DebugTableViewCellModel {
        DebugTableViewCellModel(
            title: "Delete Repo",
            cellReuseIdentifier: DebugValueTableViewCell.className,
            valueClosure: { cell in
                cell.detailTextLabel?.text = "Do it!"
            },
            actionClosure: { [weak self] cell in
                let controller = UIAlertController(
                    title: "Remove stored data?",
                    message: "You may need to restart bots and services to keep using the app.",
                    preferredStyle: .actionSheet
                )
                controller.addAction(UIAlertAction(title: "Repo and View", style: .destructive) { [weak self] _ in
                    self?.purgeRepoAndView()
                })
                controller.addAction(UIAlertAction(title: "Just view DB", style: .destructive) { _ in
                    self?.purgeJustViewDB()
                })
                controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    controller.dismiss(animated: true, completion: nil)
                })
                self?.present(alertController: controller, sourceView: cell)
            }
        )
    }

    private func actions() -> DebugTableViewController.Settings {
        var cells: [DebugTableViewCellModel] = []
        if GoBot.shared.bot.isRunning {
            cells += [publishCell]
        }
        cells += [fullFsckAndRepairCell, deleteRepoCell]
        return ("Actions", cells, nil)
    }

    // MARK: View Database

    private func viewDB() -> DebugTableViewController.Settings {
        var cells: [DebugTableViewCellModel] = []
        do {
            let lastRx = try GoBot.shared.database.stats(table: .messagekeys)
            cells += [
                DebugTableViewCellModel(
                    title: "Last RX Seq",
                    cellReuseIdentifier: DebugValueTableViewCell.className,
                    valueClosure: { cell in
                        cell.detailTextLabel?.text = String(lastRx)
                    },
                    actionClosure: nil
                )
            ]
        } catch {
            Log.unexpected(.apiError, "view db stats failed")
            Log.optional(error)
            return ("View Database Error: \(error.localizedDescription)", [], nil)
        }
        
        return ("View Database", cells, nil)
    }

    // MARK: Repo Information
    
    private func repoInfo() -> DebugTableViewController.Settings {
        var stats: ScuttlegobotRepoCounts
        do {
            stats = try GoBot.shared.bot.repoStats()
        } catch {
            Log.unexpected(.apiError, "repo Info stats failed")
            Log.optional(error)
            return ("Repo Stats Error: \(error.localizedDescription)", [], nil)
        }
        var settings: [DebugTableViewCellModel] = []
        settings += [
            DebugTableViewCellModel(
                title: "Messages",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.detailTextLabel?.text = String(stats.messages)
                },
                actionClosure: nil
            )
        ]
        return ("Repo Information", settings, nil)
    }
}
