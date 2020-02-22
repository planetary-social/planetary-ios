//
//  DebugUserDirectoryViewController.swift
//  FBTT
//
//  Created by Christoph on 6/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DebugUserDirectoryViewController: DebugTableViewController {

    var context: Onboarding.Context?
    private var users: [Person] = []
    private var selectedUsers: [Person] = []

    private let errorTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "User Directory"
    }

    internal override func updateSettings() {
        self.settings = [self.operations(), self.directory()]
        super.updateSettings()
    }

    private func operations() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Tap to get the user directory",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.text = self.users.count > 0 ? "\(self.users.count)" : ""
            },
                                             actionClosure:
            {
                cell in
                cell.showActivityIndicator()
                VerseAPI.directory() {
                    [weak self] people, error in
                    Log.optional(error)
                    self?.users = people
                    self?.updateSettings()
                    cell.hideActivityIndicator()
                }
            })]

        settings += [DebugTableViewCellModel(title: "Tap to follow selected users",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in

                guard let context = self.context ?? Onboarding.Context.fromCurrentAppConfiguration() else {
                    self.errorTextView.text = "Cannot follow without Onboarding.context"
                    return
                }

                cell.showActivityIndicator()

                // there must be a more elegant way to format this?
                let identities = self.selectedUsers.filter
                    { $0.identity.isValidIdentifier }.compactMap
                    { $0.identity }

                Onboarding.follow(identities, context: context) {
                    [weak self] result, contacts, errors in
                    cell.detailTextLabel?.text = result.successOrFailed
                    let total = contacts.count + errors.count
                    let text = "Followed \(contacts.count) of \(total), \(errors.count) errors"
                    self?.errorTextView.text = text
                    cell.hideActivityIndicator()
                    self?.selectedUsers = []
                    self?.updateSettings()
                }
            })]

        settings += [DebugTableViewCellModel(title: "Tap to list me in the user directory",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                cell in
                guard let me = self.context?.person?.identity ?? Bots.current.identity else {
                    self.errorTextView.text = "Cannot be listed without an Onboarding.Context.person or logged in Identity"
                    return
                }
                cell.showActivityIndicator()
                VerseAPI.directory(show: me) {
                    [weak self] result, error in
                    cell.detailTextLabel?.text = result.successOrFailed
                    self?.errorTextView.text = self?.string(for: error)
                    cell.hideActivityIndicator()
                }
            })]

        settings += [DebugTableViewCellModel(title: "Tap to hide me from the user directory",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                cell in
                guard let me = self.context?.person?.identity ?? Bots.current.identity else {
                    self.errorTextView.text = "Cannot join without an Onboarding.Context.person or logged in Identity"
                    return
                }
                VerseAPI.directory(hide: me) {
                    [weak self] result, error in
                    cell.detailTextLabel?.text = result.successOrFailed
                    self?.errorTextView.text = self?.string(for: error)
                    cell.hideActivityIndicator()
                }
            })]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.errorTextView)
            },
                                             actionClosure: nil)]

        return ("Actions", settings, nil)
    }

    private func directory() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        for user in self.users {
            settings += [DebugTableViewCellModel(title: user.name,
                                                 cellReuseIdentifier: DebugValueTableViewCell.className,
                                                 valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = user.identity
                },
                                                 actionClosure:
                {
                    [unowned self] cell in
                    self.select(user, on: cell)
                })]
        }

        return ("Directory", settings, nil)
    }

    private func select(_ user: Person, on cell: UITableViewCell) {
        if let index = self.selectedUsers.firstIndex(of: user) {
            self.selectedUsers.remove(at: index)
            cell.accessoryType = .none
        } else {
            self.selectedUsers += [user]
            cell.accessoryType = .checkmark
        }
    }
}
