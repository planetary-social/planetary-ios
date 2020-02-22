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
        VerseAPI.me.isInDirectory() {
            [weak self] inDirectory, _ in
            AppController.shared.hideProgress()
            self?.inDirectory = inDirectory
            self?.updateSettings()
        }
    }

    private func toggle(inDirectory: Bool) {
        self.inDirectory = inDirectory
        self.updateSettings()
        AppController.shared.showProgress()
        VerseAPI.me.showInDirectory(inDirectory) {
            [weak self] result, _ in
            AppController.shared.hideProgress()
            self?.updateSettings()
        }
    }
}
