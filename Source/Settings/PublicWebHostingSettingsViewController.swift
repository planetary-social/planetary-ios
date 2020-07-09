//
//  PublicWebHostingSettingsViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/8/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class PublicWebHostingSettingsViewController: DebugTableViewController {

    private var isPublicWebHostingEnabled: Bool? = nil

    convenience init(enabled: Bool? = nil) {
        self.init()
        self.isPublicWebHostingEnabled = enabled
    }

    private lazy var show = DebugTableViewCellModel(title: Text.showMeInUserDirectory.text,
                                                    valueClosure:
        {
            [unowned self] cell in
            cell.accessoryType = .none
            guard let isPublicWebHostingEnabled = self.isPublicWebHostingEnabled else { return }
            cell.accessoryType = isPublicWebHostingEnabled ? .checkmark : .none
        },
                                                    actionClosure:
        {
            [unowned self] cell in
            self.toggle(isPublicWebHostingEnabled: true)
        })

    private lazy var hide = DebugTableViewCellModel(title: Text.hideMeFromUserDirectory.text,
                                                    valueClosure:
        {
            [unowned self] cell in
            cell.accessoryType = .none
            guard let isPublicWebHostingEnabled = self.isPublicWebHostingEnabled else { return }
            cell.accessoryType = isPublicWebHostingEnabled ? .none : .checkmark
        },
                                                    actionClosure:
        {
            [unowned self] cell in
            self.toggle(isPublicWebHostingEnabled: false)
        })

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = Text.showMeInDirectory.text
        self.updateSettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.checkPublicWebHostingIfNecessary()
    }

    private func checkPublicWebHostingIfNecessary() {
        guard self.isPublicWebHostingEnabled == nil else { return }
        AppController.shared.showProgress()
        Bots.current.about { [weak self] (about, error) in
            AppController.shared.hideProgress()
            self?.isPublicWebHostingEnabled = about?.publicWebHosting ?? false
            self?.updateSettings()
        }
    }

    internal override func updateSettings() {
        self.settings = [("", [self.show, self.hide], Text.userDirectoryMessage.text)]
        super.updateSettings()
    }

    private func toggle(isPublicWebHostingEnabled: Bool) {
        guard let identity = Bots.current.identity else {
            return
        }
        self.isPublicWebHostingEnabled = isPublicWebHostingEnabled
        self.updateSettings()
        AppController.shared.showProgress()

        Bots.current.about { [weak self] (about, error) in
            if let error = error {
                AppController.shared.hideProgress()
                self?.alert(error: error)
            } else {
                let newAbout = about?.mutatedCopy(publicWebHosting: isPublicWebHostingEnabled)
                Bots.current.publish(content: newAbout) { (_, error) in
                    AppController.shared.hideProgress()
                    if let error = error {
                        self?.alert(error: error)
                    }
                    self?.updateSettings()
                }
            }
        }
    }

}
