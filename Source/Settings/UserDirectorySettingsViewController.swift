//
//  DirectorySettingsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class UserDirectorySettingsViewController: DebugTableViewController {

    private lazy var show = DebugTableViewCellModel(title: Text.showMeInUserDirectory.text,
                                                    valueClosure:
        {
            [unowned self] cell in
            cell.accessoryType = .none
            guard let inDirectory = self.inDirectory else { return }
            cell.accessoryType = inDirectory ? .checkmark : .none
        },
                                                    actionClosure:
        {
            [unowned self] cell in
            self.toggle(inDirectory: true)
        })

    private lazy var hide = DebugTableViewCellModel(title: Text.hideMeFromUserDirectory.text,
                                                    valueClosure:
        {
            [unowned self] cell in
            cell.accessoryType = .none
            guard let inDirectory = self.inDirectory else { return }
            cell.accessoryType = inDirectory ? .none : .checkmark
        },
                                                    actionClosure:
        {
            [unowned self] cell in
            self.toggle(inDirectory: false)
        })

    private var inDirectory: Bool? = nil

    // TODO include optional initial state
    convenience init(inDirectory: Bool? = nil) {
        self.init()
        self.inDirectory = inDirectory
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.showMeInDirectory.text
        self.updateSettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.checkInDirectoryIfNecessary()
    }

    internal override func updateSettings() {
        self.settings = [("", [self.show, self.hide], Text.userDirectoryMessage.text)]
        super.updateSettings()
    }

    private func checkInDirectoryIfNecessary() {
        guard self.inDirectory == nil else { return }
        AppController.shared.showProgress()
        DirectoryAPI.shared.me { [weak self] (person, error) in
            DispatchQueue.main.async { [weak self] in
                AppController.shared.hideProgress()
                self?.inDirectory = person?.in_directory
                self?.updateSettings()
            }
        }
    }

    private func toggle(inDirectory: Bool) {
        guard let identity = Bots.current.identity else {
            return
        }
        self.inDirectory = inDirectory
        self.updateSettings()
        AppController.shared.showProgress()
        if inDirectory {
            DirectoryAPI.shared.directory(show: identity) { [weak self] (_, _) in
                DispatchQueue.main.async { [weak self] in
                    AppController.shared.hideProgress()
                    self?.updateSettings()
                }
            }
        } else {
            DirectoryAPI.shared.directory(hide: identity) { [weak self] (_, _) in
                DispatchQueue.main.async { [weak self] in
                    AppController.shared.hideProgress()
                    self?.updateSettings()
                }
            }
        }
    }
}
