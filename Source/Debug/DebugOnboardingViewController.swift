//
//  DebugOnboardingViewController.swift
//  FBTT
//
//  Created by Christoph on 5/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DebugOnboardingViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Onboarding"
    }

    internal override func updateSettings() {
        self.settings = [self.userInput(),
                         self.verification(),
                         self.start(),
                         self.followBack()]
        super.updateSettings()
    }

    // MARK: User input

    private let countryTextField: UITextField = {
        let view = UITextField()
        view.keyboardType = .numberPad
        view.placeholder = "Country code (digits only)"
        view.text = "1"
        return view
    }()

    private let phoneTextField: UITextField = {
        let view = UITextField()
        view.keyboardType = .numberPad
        view.placeholder = "Phone number (digits only)"
        return view
    }()

    private let nameTextField: UITextField = {
        let view = UITextField()
        view.placeholder = "Name"
        view.text = "Debug \(Date().shortDateTimeString)"
        return view
    }()

    private var birthdate = Date.random(in: 1975)

    private lazy var birthdateTextField: UITextField = {
        let view = UITextField()
        view.isEnabled = false
        view.text = self.birthdate.shortDateString
        return view
    }()

    private func userInput() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.countryTextField, insets: .debugTableViewCell)
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.phoneTextField, insets: .debugTableViewCell)
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.nameTextField, insets: .debugTableViewCell)
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.birthdateTextField, insets: .debugTableViewCell)
            },
                                             actionClosure:
            {
                [unowned self] cell in
                let years = Int((arc4random() % 50) + 10)
                self.birthdate = Date.random(yearsFromNow: -years)
                self.birthdateTextField.text = self.birthdate.shortDateString
            })]

        return ("User Input", settings, nil)
    }

    private func validateUserInput() -> Bool {

        guard let country = self.countryTextField.text, country.count > 0 else {
            self.alert(title: "Missing country code",
                       message: "Cannot start onboarding without a country code",
                       cancelTitle: "OK")
            return false
        }

        guard let phone = self.phoneTextField.text, phone.count > 0 else {
            self.alert(title: "Missing phone number",
                       message: "Cannot start onboarding without a phone number",
                       cancelTitle: "OK")
            return false
        }

        guard let name = self.nameTextField.text, name.count > 0 else {
            self.alert(title: "Missing name",
                       message: "Cannot start onboarding without a name",
                       cancelTitle: "OK")
            return false
        }

        self.resignFirstResponders()
        return true
    }

    // MARK: Verification

    private let codeTextField: UITextField = {
        let view = UITextField()
        view.keyboardType = .numberPad
        view.textContentType = .oneTimeCode
        view.placeholder = "Received code (digits only)"
        return view
    }()

    private let verificationErrorTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    private func verification() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Tap to request code",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                guard self.validateUserInput() else { return }
                cell.isUserInteractionEnabled = false
                cell.showActivityIndicator()
                Onboarding.requestCode(country: self.countryTextField.text ?? "",
                                       phone: self.phoneTextField.text ?? "")
                {
                    [unowned self] result, error in
                    cell.isUserInteractionEnabled = true
                    cell.hideActivityIndicator()
                    cell.detailTextLabel?.text = result.successOrFailed
                    self.verificationErrorTextView.text = self.string(for: error)
                }
            }
        )]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.codeTextField, insets: .debugTableViewCell)
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Tap to verify code",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                self.codeTextField.resignFirstResponder()
                cell.isUserInteractionEnabled = false
                cell.showActivityIndicator()
                Onboarding.verifyCode(self.codeTextField.text ?? "",
                                      country: self.countryTextField.text ?? "",
                                      phone: self.phoneTextField.text ?? "")
                {
                    [unowned self] result, error in
                    cell.isUserInteractionEnabled = true
                    cell.hideActivityIndicator()
                    cell.detailTextLabel?.text = result.successOrFailed
                    self.verificationErrorTextView.text = self.string(for: error)
                }
            }
        )]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.verificationErrorTextView)
            },
                                             actionClosure: nil)]

        return ("Verification", settings, nil)
    }

    // MARK: Start onboarding

    var context: Onboarding.Context?

    private let startErrorTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    private func startOnboarding(from cell: UITableViewCell) {

        guard self.validateUserInput() else { return }

        AppController.shared.showProgress()
        cell.showActivityIndicator()
        Bots.current.logout() {
            error in
            let number = "\(self.countryTextField.text ?? "")\(self.phoneTextField.text ?? "")"
            Onboarding.start(birthdate: self.birthdate,
                             phone: number,
                             name: self.nameTextField.text!)
            {
                context, error in
                self.context = context
                cell.hideActivityIndicator()
                self.startErrorTextView.text = self.string(for: error)
                AppController.shared.hideProgress()
            }
        }
    }

    private func start() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Tap to create secret and join",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                guard self.validateUserInput() else { return }
                self.confirm(
                    from: cell,
                    title: "Warning!",
                    message: "Starting a new onboarding session will log out your current identity and create a new identity.  Are you sure you want to do this?",
                    isDestructive: true,
                    confirmTitle: "Continue",
                    confirmClosure: { self.startOnboarding(from: cell) }
                )
            })]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.startErrorTextView)
            },
                                             actionClosure: nil)]

        return ("Start onboarding", settings, nil)
    }

    // MARK: Follow

    private let followErrorTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    // MARK: Follow back

    private let followBackErrorTextView: UITextView = {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    private func followBack() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Verse pubs are reachable",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                cell in
                cell.showActivityIndicator()
                PubAPI.shared.pubsAreOnline() { online, error in
                    Log.optional(error)
                    DispatchQueue.main.async {
                        cell.hideActivityIndicator()
                        cell.detailTextLabel?.text = "\(online)"
                    }
                }
            },
                                             actionClosure: nil)]

        settings += [DebugTableViewCellModel(title: "Tap to be followed by Verse pubs",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: nil,
                                             actionClosure:
            {
                [unowned self] cell in
                guard let identity = AppConfiguration.current?.identity else { return }
                cell.isUserInteractionEnabled = false
                cell.showActivityIndicator()
                self.resignFirstResponders()
                Onboarding.invitePubsToFollow(identity) {
                    [unowned self] result, error in
                    cell.isUserInteractionEnabled = true
                    cell.hideActivityIndicator()
                    cell.detailTextLabel?.text = result.successOrFailed
                    self.followBackErrorTextView.text = self.string(for: error)
                }
            })]

        settings += [DebugTableViewCellModel(title: "",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure:
            {
                [unowned self] cell in
                Layout.fill(view: cell.contentView, with: self.followBackErrorTextView)
            },
                                             actionClosure: nil)]

        return ("Follow Back", settings, nil)
    }

    private func resignFirstResponders() {
        self.countryTextField.resignFirstResponder()
        self.phoneTextField.resignFirstResponder()
        self.codeTextField.resignFirstResponder()
    }
}

extension DebugTableViewController {

    func string(for error: Error?) -> String {
        guard let error = error else { return "No error" }
        return "\(error)"
    }
}

extension Bool {

    var successOrFailed: String {
        return self ? "success" : "failed"
    }
}
