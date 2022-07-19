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
    
    private func status() -> DebugTableViewController.Settings {
        
        var settings: [DebugTableViewCellModel] = []
        
        settings += [DebugTableViewCellModel(title: "Version",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = GoBot.shared.version
            },
                                             actionClosure: nil
        )]
        
        settings += [DebugTableViewCellModel(title: "Running",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                let toggle = UISwitch()
                toggle.isOn = GoBot.shared.bot.isRunning
                toggle.addTarget(self, action: #selector(self.runningToggleDidChange), for: .valueChanged)
                cell.accessoryView = toggle
            },
                                             actionClosure: nil
        )]
        let cnt = GoBot.shared.bot.openConnections()
        if cnt > 0 {
            settings += [DebugTableViewCellModel(title: "#Connections",
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure: {
                    cell in
                    cell.detailTextLabel?.text = String(cnt)
                },
                                                 actionClosure: nil
            )]
            
            settings += [DebugTableViewCellModel(title: "Disconnect all",
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure: {
                    cell in
                    cell.accessoryType = .detailButton
                },
                                                 actionClosure: {
                    _ in
                    DispatchQueue.global(qos: .utility).async {
                        GoBot.shared.bot.disconnectAll()
                    }
                }
            )]
        }
        
        return ("Status", settings, nil)
    }
    
    private func actions() -> DebugTableViewController.Settings {
        var a: [DebugTableViewCellModel] = []
        
        if GoBot.shared.bot.isRunning {
            
            a += [DebugTableViewCellModel(title: "Publish",
                                     cellReuseIdentifier: DebugValueTableViewCell.className,
                                     valueClosure: {
                    cell in
                    cell.accessoryType = .detailButton
                },
                                     actionClosure: {
                    _ in
                    let publishCtrl = SimplePublishViewController()
                    self.navigationController?.pushViewController(publishCtrl, animated: true)
                }
            )]
            
            do {
                let (_, diff) = try GoBot.shared.needsViewFill()
                if diff > 0 {
                    // TODO: add complete Fill trigger
                    a += [DebugTableViewCellModel(title: "TODO: add complete Fill trigger",
                                                  cellReuseIdentifier: DebugValueTableViewCell.className,
                                                  valueClosure: {
                            cell in
                            cell.accessoryType = .detailDisclosureButton
                        },
                                                  actionClosure: nil
                    )]
                }
            } catch {
                Log.optional(error)	
            }
        }
        
        a += [DebugTableViewCellModel(title: "Full FSCK and Repair",
                                        cellReuseIdentifier: DebugValueTableViewCell.className,
                                        valueClosure: {
                  cell in
                  cell.detailTextLabel?.text = "Run"
              },
                                        actionClosure: {
                _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    let (worked, _) = GoBot.shared.bot.fsckAndRepair()
                    guard worked else {
                        Log.unexpected(.botError, "manual fsck failed")
                        return
                    }
                }
              }
          )]

        a += [DebugTableViewCellModel(title: "Delete Repo",
                                      cellReuseIdentifier: DebugValueTableViewCell.className,
                                      valueClosure: {
                cell in
                cell.detailTextLabel?.text = "Do it!"
            },
                                      actionClosure: {
                cell in
                self.promptPurge(from: cell)
            }
        )]
        
        return ("Actions", a, nil)
    }
    
    private func viewDB() -> DebugTableViewController.Settings {
        var cells: [DebugTableViewCellModel] = []
        
        do {
            let lastRx = try GoBot.shared.database.stats(table: .messagekeys)
            
            cells += [DebugTableViewCellModel(title: "Last RX Seq",
                                              cellReuseIdentifier: DebugValueTableViewCell.className,
                                              valueClosure: {
                    cell in
                    cell.detailTextLabel?.text = String(lastRx)
                },
                                              actionClosure: nil
                )]
        } catch {
            Log.unexpected(.apiError, "view db stats failed")
            Log.optional(error)
            return ("View Database Error: \(error.localizedDescription)", [], nil)
        }
        
        return ("View Database", cells, nil)
    }
    
    private func repoInfo() -> DebugTableViewController.Settings {
        var stats: ScuttlegobotRepoCounts
        do {
           stats = try GoBot.shared.bot.repoStatus()
        } catch {
            Log.unexpected(.apiError, "repo Info stats failed")
            Log.optional(error)
            return ("Repo Stats Error: \(error.localizedDescription)", [], nil)
        }
        
        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Messages",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.detailTextLabel?.text = String(stats.messages)
            },
                                             actionClosure: nil // TODO: view rootLog
        )]
        return ("Repo Information", settings, nil)
    }
}

extension GoBotViewController {
    
    func promptPurge(from view: UIView) {
        
        let controller = UIAlertController(title: "Remove stored data?",
                                           message: "You may need to restart bots and services to keep using the app.",
                                           preferredStyle: .actionSheet)
        
        let delRepo = UIAlertAction(title: "Repo and View", style: .destructive) {
            _ in
            do {
                if GoBot.shared.bot.isRunning {
                    _ = GoBot.shared.bot.logout()
                }

                // TODO https://app.asana.com/0/914798787098068/1153254864207581/f
                // TODO crash when deleting a repo without an active configuration
                GoBot.shared.database.close()
                let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
                let path = appSupportDir
                    .appending("/FBTT/")
                    .appending(AppConfiguration.current!.network!.hexEncodedString())
                try FileManager.default.removeItem(atPath: path)
                Log.info("repo deleted.. should stop and restart sbot")
            } catch {
                Log.unexpected(.apiError, "purge error")
                Log.optional(error)
            }
            self.updateSettings()
        }
        controller.addAction(delRepo)
        
        let delView = UIAlertAction(title: "Just view DB", style: .destructive) {
            _ in
            do {
                if GoBot.shared.bot.isRunning {
                    _ = GoBot.shared.bot.logout()
                }
                let dbPath = GoBot.shared.database.currentPath
                GoBot.shared.database.close()
                try FileManager.default.removeItem(atPath: dbPath)
            } catch {
                Log.unexpected(.apiError, "purge error")
                Log.optional(error)
            }
            self.updateSettings()
        }
        controller.addAction(delView)
        
        // cancel
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) {
            _ in
            controller.dismiss(animated: true, completion: nil)
        })

        self.present(alertController: controller, sourceView: view)
    }
}
