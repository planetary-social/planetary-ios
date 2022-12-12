//
//  AppConfigurationViewController.swift
//  FBTT
//
//  Created by Christoph on 5/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class AppConfigurationViewController: DebugTableViewController {

    private let configuration: AppConfiguration
    private var secret: Secret?
    private var canDeleteConfiguration = true
    private var canEditConfiguration = false

    init(with configuration: AppConfiguration) {
        self.configuration = configuration
        super.init(style: .insetGrouped)
        self.navigationItem.title = self.configuration.name
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Select",
            style: .plain,
            target: self,
            action: #selector(selectConfiguration)
        )
    }

    convenience init(with secret: Secret) {
        self.init(with: AppConfiguration(with: secret))
        self.secret = secret
        self.canDeleteConfiguration = false
        self.canEditConfiguration = true
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.load()
        self.refresh()
    }

    // MARK: Settings

    private func load() {
        settings = [
            configurationName(),
            onboarding(),
            statistics(),
            identityAndSecret(),
            networks(),
            hmacKeys(),
            bots()
        ]
    }

    private func refresh() {
        self.tableView.reloadData()
        self.navigationItem.rightBarButtonItem?.isEnabled = self.configuration.canLaunch
    }

    private lazy var nameField: UITextField = {
        let field = UITextField(frame: .zero)
        field.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        field.clearButtonMode = .whileEditing
        field.placeholder = "Configuration name"
        return field
    }()

    private func configurationName() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    guard let self = self else { return }
                    Layout.fill(view: cell.contentView, with: self.nameField, insets: .debugTableViewCell)
                    self.nameField.text = self.configuration.name
                    self.nameField.isEnabled = self.canEditConfiguration
                    self.nameField.isUserInteractionEnabled = self.canEditConfiguration
                },
                actionClosure: nil
            )
        ]

        if self.canDeleteConfiguration {
            settings += [
                DebugTableViewCellModel(
                    title: "Delete",
                    cellReuseIdentifier: DebugValueTableViewCell.className,
                    valueClosure: { cell in
                        cell.textLabel?.textColor = .red
                        let enabled = AppConfigurations.current.count > 1
                        cell.textLabel?.isEnabled = enabled
                        cell.isUserInteractionEnabled = enabled
                    },
                    actionClosure: { [weak self] cell in
                        guard let self = self else { return }
                        self.confirm(
                            from: cell,
                            message: "Are you sure you want to delete this secret and configuration?  Unless you " +
                            "have copied the secret somewhere you will not be able to restore this identity.",
                            confirmTitle: "Delete"
                        ) {
                            AppConfigurations.delete(self.configuration)
                            self.navigationController?.popToRootViewController(animated: true)
                        }
                    }
                )
            ]
        }

        return ("Configuration name", settings, nil)
    }

    private func onboarding() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "Status",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    if let self {
                        cell.detailTextLabel?.text = Onboarding.status(for: self.configuration.identity).rawValue
                    }
                },
                actionClosure: nil
            ),
            DebugTableViewCellModel(
                title: "Joined Planetary Network",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.detailTextLabel?.text = String(self.configuration.joinedPlanetarySystem)
                }
            )
        ]

        return ("Onboarding", settings, nil)
    }
    
    // swiftlint:disable function_body_length
    private func statistics() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "Published messages",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    cell.detailTextLabel?.text = "\(String(describing: self?.configuration.numberOfPublishedMessages))"
                }
            )
        ]
        
        settings += [
            DebugTableViewCellModel(
                title: Localized.Debug.resetForkedFeedProtection.text,
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    let enabled = AppConfiguration.current == self?.configuration
                    cell.textLabel?.isEnabled = enabled
                    cell.isUserInteractionEnabled = enabled
                    cell.textLabel?.textColor = .systemBlue
                },
                actionClosure: { [weak self] cell in
                    self?.confirm(
                        from: cell,
                        message: Localized.Debug.resetForkedFeedProtectionDescription.text,
                        isDestructive: true,
                        confirmTitle: Localized.Debug.reset.text
                    ) {
                        guard let self = self,
                            let bot = self.configuration.bot else {
                            self?.alert(message: Localized.Debug.noBotConfigured.text)
                            return
                        }
                        
                        Task {
                            AppController.shared.showProgress()
                            // Make sure the view database is fully synced with the backing store.
                            var fullySynced = false
                            while !fullySynced {
                                do {
                                    let (_, finished) = try await bot.refresh(load: .long)
                                    fullySynced = finished
                                } catch {
                                    self.alert(error: error)
                                    return
                                }
                            }
                            let statistics = await bot.statistics()
                            self.configuration.numberOfPublishedMessages = statistics.repo.numberOfPublishedMessages
                            self.configuration.apply()
                            UserDefaults.standard.set(true, forKey: "prevent_feed_from_forks")
                            UserDefaults.standard.synchronize()
                            self.tableView.reloadData()
                            Log.info(
                                "User reset number of published messages " +
                                "to \(self.configuration.numberOfPublishedMessages)"
                            )
                            AppController.shared.hideProgress()
                        }
                    }
                }
            )
        ]

        return ("Statistics", settings, nil)
    }
    // swiftlint:enable function_body_length

    private func identityAndSecret() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    cell.textLabel?.isEnabled = ((self?.canEditConfiguration) != nil)
                    cell.textLabel?.numberOfLines = 0
                    cell.textLabel?.text = self?.configuration.identity
                },
                actionClosure: { cell in
                    UIPasteboard.general.string = cell.textLabel?.text
                }
            ),
            DebugTableViewCellModel(
                title: "",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { [weak self] cell in
                    cell.textLabel?.isEnabled = ((self?.canEditConfiguration) != nil)
                    cell.textLabel?.numberOfLines = 1
                    let secret = self?.configuration.secret
                    cell.textLabel?.text = secret?.jsonStringUnescaped()
                },
                actionClosure: { cell in
                    UIPasteboard.general.string = cell.textLabel?.text
                }
            )
        ]

        return ("Identity and secret (tap to copy)", settings, nil)
    }

    private func networks() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "SSB",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    let network = Environment.Networks.mainNet
                    cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                    cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                    cell.detailTextLabel?.text = Environment.Networks.mainNet.key.string
                    let selected = self.configuration.network == network.key
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.textLabel?.isEnabled = self.canEditConfiguration
                    cell.isUserInteractionEnabled = self.canEditConfiguration
                },
                actionClosure: { [weak self] _ in
                    self?.configuration.ssbNetwork = Environment.Networks.mainNet
                    self?.refresh()
                }
            ),
            DebugTableViewCellModel(
                title: "Planetary Test Network",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    let network = Environment.Networks.test
                    cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                    cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                    cell.detailTextLabel?.text = network.key.string
                    let selected = self.configuration.network == network.key
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.textLabel?.isEnabled = self.canEditConfiguration
                    cell.isUserInteractionEnabled = self.canEditConfiguration
                },
                actionClosure: { [weak self] _ in
                    self?.configuration.ssbNetwork = Environment.Networks.test
                    self?.refresh()
                }
            )
        ]
        
        return ("Networks", settings, nil)
    }

    private func hmacKeys() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "Off",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                    cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                    let selected = self.configuration.hmacKey == nil
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.isEnabled = false
                }
            ),
            DebugTableViewCellModel(
                title: "Planetary Test Network",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    let network = Environment.Networks.test
                    cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                    cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                    cell.detailTextLabel?.text = network.hmac?.string
                    let selected = self.configuration.hmacKey == network.hmac
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.isEnabled = false
                },
                actionClosure: nil
            )
        ]

        return ("HMAC Signing Key", settings, nil)
    }

    private func bots() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [
            DebugTableViewCellModel(
                title: "FakeBot",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    let selected = self.configuration.bot?.name == "FakeBot"
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.textLabel?.isEnabled = self.canEditConfiguration
                    cell.isUserInteractionEnabled = self.canEditConfiguration
                },
                actionClosure: { [weak self] _ in
                    self?.configuration.bot = Bots.bot(named: "FakeBot")
                    self?.refresh()
                }
            ),
            DebugTableViewCellModel(
                title: "GoBot",
                cellReuseIdentifier: DebugValueTableViewCell.className,
                valueClosure: { cell in
                    let selected = self.configuration.bot?.name == "GoBot"
                    cell.accessoryType = selected ? .checkmark : .none
                    cell.textLabel?.isEnabled = self.canEditConfiguration
                    cell.isUserInteractionEnabled = self.canEditConfiguration
                },
                actionClosure: { [weak self] _ in
                    self?.configuration.bot = Bots.bot(named: "GoBot")
                    self?.refresh()
                }
            )
        ]

        return ("Bots", settings, nil)
    }

    // MARK: Actions

    @objc
    private func selectConfiguration() {
        AppController.shared.showProgress(after: 0, statusText: Localized.loggingOut.text)
        guard let name = self.nameField.text else { return }
        guard self.configuration.canLaunch else { return }
        self.configuration.name = name
        self.configuration.apply()
        AppConfigurations.add(self.configuration)
        AppController.shared.dismissSettingsViewController {
            Task {
                await AppController.shared.relaunch()
                AppController.shared.hideProgress()
            }
        }
    }

    @objc
    private func textFieldDidChange(textField: UITextField) {
        self.configuration.name = textField.text ?? ""
    }
}
