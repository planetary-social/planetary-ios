//
//  BotsViewController.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BotsViewController: UIViewController {

    // MARK: Lifecycle

    @available(*, deprecated)
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "Bots"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.darkGray
        self.addSubviews()
    }

    // MARK: Layout

    private func addSubviews() {

        var button = UIButton(type: .custom)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .fill
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -128, bottom: 0, right: 0)
        button.setImage(UIImage(named: "gobot-icon"), for: .normal)
        button.setTitle("GoBot", for: .normal)
        button.titleLabel?.layer.shadowColor = UIColor.black.cgColor
        button.titleLabel?.layer.shadowOffset = CGSize.zero
        button.titleLabel?.layer.shadowOpacity = 1
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        button.addTarget(self, action: #selector(goBotButtonTouchUpInside), for: .touchUpInside)
        self.view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 128).isActive = true
        button.heightAnchor.constraint(equalToConstant: 128).isActive = true
        button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -100).isActive = true

        button = UIButton(type: .custom)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .fill
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -128, bottom: 0, right: 0)
        button.setImage(UIImage(named: "fakebot-icon"), for: .normal)
        button.setTitle("FakeBot", for: .normal)
        button.titleLabel?.layer.shadowColor = UIColor.black.cgColor
        button.titleLabel?.layer.shadowOffset = CGSize.zero
        button.titleLabel?.layer.shadowOpacity = 1
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(fakeBotButtonTouchUpInside), for: .touchUpInside)
        self.view.addSubview(button)
        button.widthAnchor.constraint(equalToConstant: 128).isActive = true
        button.heightAnchor.constraint(equalToConstant: 128).isActive = true
        button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 100).isActive = true

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20)
        label.numberOfLines = 0
        label.text = "Shake to open\ndebug menu"
        label.textAlignment = .center
        label.textColor = UIColor.gray
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)
        label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -50).isActive = true
    }

    // MARK: Actions

    @objc func goBotButtonTouchUpInside() {
        self.confirmIdentity(bot: Bots.current)
    }

    @objc func fakeBotButtonTouchUpInside() {
        self.confirmIdentity(bot: Bots.current)
    }

    private func confirmIdentity(bot: Bot) {
        if let _ = AppConfiguration.current?.identity {
            self.start(bot: bot)
        } else {
            self.promptToOpenDebugMenu()
        }
    }

    private func promptToOpenDebugMenu() {
        let controller = UIAlertController(title: "No identity selected",
                                           message: "Please add and select an identity from the Debug menu",
                                           preferredStyle: .actionSheet)
        var action = UIAlertAction(title: "Cancel", style: .cancel) {
            _ in
            controller.dismiss(animated: true, completion: nil)
        }
        controller.addAction(action)

        action = UIAlertAction(title: "Debug menu", style: .default) {
            _ in
            AppController.shared.showDebug()
        }
        controller.addAction(action)
        self.present(controller, animated: true, completion: nil)
    }

    private func start(bot: Bot) {

        guard let secret = AppConfiguration.current?.secret else {
            assertionFailure("No selected identity from IdentityManager")
            return
        }

        guard let network = AppConfiguration.current?.networkKey else {
            assertionFailure("No specified network key from UserDefaults")
            return
        }

        // this set Bots.current
        Bots.select(bot)

        bot.login(network: network, hmacKey: AppConfiguration.current?.hmacKey, secret: secret) {
            [weak self] error in
            if let e = error {
                Log.unexpected(.apiError, "login failed")
                Log.optional(e)
                return
            }
            let controller = HomeViewController()
            self?.navigationController?.pushViewController(controller, animated: true)
        }
    }
}
