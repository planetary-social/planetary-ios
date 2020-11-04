//
//  AppConfigurationViewController.swift
//  FBTT
//
//  Created by Christoph on 5/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// TODO https://app.asana.com/0/914798787098068/1122607002060947/f
// TODO deprecate identity manager
class AppConfigurationViewController: DebugTableViewController {

    private let configuration: AppConfiguration
    private var secret: Secret?
    private var canDeleteConfiguration = true
    private var canEditConfiguration = false

    init(with configuration: AppConfiguration) {
        self.configuration = configuration
        super.init(style: .grouped)
        self.navigationItem.title = self.configuration.name
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Select",
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(selectConfiguration))
    }

    convenience init(with secret: Secret) {
        self.init(with: AppConfiguration(with: secret))
        self.secret = secret
        self.canDeleteConfiguration = false
        self.canEditConfiguration = true
    }
    
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
        self.settings = [self.configurationName(),
                         self.onboarding(),
                         self.statistics(),
                         self.identityAndSecret(),
                         self.networks(),
                         self.hmacKeys(),
                         self.bots()]
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

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.nameField, insets: .debugTableViewCell)
                self.nameField.text = self.configuration.name
                self.nameField.isEnabled = self.canEditConfiguration
                self.nameField.isUserInteractionEnabled = self.canEditConfiguration
            },
                                             actionClosure: nil)]

        if self.canDeleteConfiguration {
            settings += [DebugTableViewCellModel(title: "Delete",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.textLabel?.textColor = .red
                let enabled = AppConfigurations.current.count > 1
                cell.textLabel?.isEnabled = enabled
                cell.isUserInteractionEnabled = enabled
            },
                                             actionClosure:
            {
                [unowned self] cell in
                self.confirm(message: "Are you sure you want to delete this secret and configuration?  Unless you have copied the secret somewhere you will not be able to restore this identity.",
                             confirmTitle: "Delete",
                             confirmClosure:
                    {
                        AppConfigurations.delete(self.configuration)
                        self.navigationController?.popToRootViewController(animated: true)
                    })
            })]
        }

        return ("Configuration name", settings, nil)
    }

    private func onboarding() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Status",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.detailTextLabel?.text = Onboarding.status(for: self.configuration.identity!).rawValue
            },
                                             actionClosure: nil)]
        

        return ("Onboarding", settings, nil)
    }
    
    private func statistics() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Published messages",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.detailTextLabel?.text = "\(self.configuration.numberOfPublishedMessages)"
            },
                                             actionClosure: nil)]
        

        return ("Statistics", settings, nil)
    }

    private func identityAndSecret() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.text = self.configuration.identity
            },
                                             actionClosure:
            {
                cell in
                UIPasteboard.general.string = cell.textLabel?.text
            }
        )]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.textLabel?.numberOfLines = 0
                guard let secret = self.configuration.secret ?? self.secret else { return }
                cell.textLabel?.text = secret.jsonStringUnescaped()
            },
                                             actionClosure:
            {
                cell in
                UIPasteboard.general.string = cell.textLabel?.text
            }
        )]

        return ("Identity and secret (tap to copy)", settings, nil)
    }

    private func networks() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "SSB",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                cell.detailTextLabel?.text = NetworkKey.ssb.string
                let selected = self.configuration.network == NetworkKey.ssb
                cell.accessoryType = selected ? .checkmark : .none
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.isUserInteractionEnabled = self.canEditConfiguration
            },
                                             actionClosure:
            {
                [unowned self] cell in
                self.configuration.network = NetworkKey.ssb
                self.refresh()
            }
        )]

        settings += [DebugTableViewCellModel(title: "Verse",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                cell.detailTextLabel?.text = NetworkKey.verse.string
                let selected = self.configuration.network == NetworkKey.verse
                cell.accessoryType = selected ? .checkmark : .none
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.isUserInteractionEnabled = self.canEditConfiguration
            },
                                             actionClosure:
            {
                [unowned self] cell in
                self.configuration.network = NetworkKey.verse
                self.refresh()
            }
        )]

        settings += [DebugTableViewCellModel(title: "Planetary",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                cell.detailTextLabel?.text = NetworkKey.planetary.string
                let selected = self.configuration.network == NetworkKey.planetary
                cell.accessoryType = selected ? .checkmark : .none
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.isUserInteractionEnabled = self.canEditConfiguration
        },
                                             actionClosure:
            {
                [unowned self] cell in
                self.configuration.network = NetworkKey.planetary
                self.refresh()
            }
        )]
        
        return ("Networks", settings, nil)
    }

    private func hmacKeys() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Off",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                let selected = self.configuration.hmacKey == nil
                cell.accessoryType = selected ? .checkmark : .none
                cell.isUserInteractionEnabled = false
                cell.textLabel?.isEnabled = false
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Verse",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                cell.detailTextLabel?.text = HMACKey.verse.string
                let selected = self.configuration.hmacKey == HMACKey.verse
                cell.accessoryType = selected ? .checkmark : .none
                cell.isUserInteractionEnabled = false
                cell.textLabel?.isEnabled = false
        },
                                             actionClosure: nil)]
        
        settings += [DebugTableViewCellModel(title: "Planetary",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = false
                cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                cell.detailTextLabel?.text = HMACKey.planetary.string
                let selected = self.configuration.hmacKey == HMACKey.planetary
                cell.accessoryType = selected ? .checkmark : .none
                cell.isUserInteractionEnabled = false
                cell.textLabel?.isEnabled = false
            },
                                             actionClosure: nil)]

        return ("HMAC Signing Key", settings, nil)
    }

    private func bots() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "FakeBot",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                let selected = self.configuration.bot?.name == "FakeBot"
                cell.accessoryType = selected ? .checkmark : .none
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.isUserInteractionEnabled = self.canEditConfiguration
            },
                                             actionClosure:
            {
                [unowned self] cell in
                self.configuration.bot = Bots.bot(named: "FakeBot")
                self.refresh()
            }
        )]

        settings += [DebugTableViewCellModel(title: "GoBot",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                let selected = self.configuration.bot?.name == "GoBot"
                cell.accessoryType = selected ? .checkmark : .none
                cell.textLabel?.isEnabled = self.canEditConfiguration
                cell.isUserInteractionEnabled = self.canEditConfiguration
            },
                                             actionClosure:
            {
                [unowned self] cell in
                self.configuration.bot = Bots.bot(named: "GoBot")
                self.refresh()
            }
        )]

        return ("Bots", settings, nil)
    }

    // MARK: Actions

    @objc private func selectConfiguration() {
        guard let name = self.nameField.text else { return }
        guard self.configuration.canLaunch else { return }
        self.configuration.name = name
        self.configuration.apply()
        AppConfigurations.add(self.configuration)
        self.navigationController?.popToRootViewController(animated: true)
    }

    @objc private func textFieldDidChange(textField: UITextField) {
        self.configuration.name = textField.text ?? ""
    }
}
