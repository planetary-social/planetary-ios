//
//  SecretViewController.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import CrashReporting

class SecretViewController: UIViewController {

    private var secret: Secret?

    private let textView: UITextView = {
        let view = UITextView()
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.systemFont(ofSize: 14)
        return view
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.text = """
                     Use the secret from your local .ssb folder.  Cut and paste the section that looks like:

                     {
                         "curve": "ed25519",
                         "public": "..... =.ed25519",
                         "private": " asdasdsadasd ==.ed25519",
                         "id": "@adasdasd=.ed25519"
                     }

                     If the text is red, then the secret is invalid.
                     """
        label.textColor = UIColor.lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setText(.deleteSecretAndIdentity)
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "Secret"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.textView.delegate = self
        self.addSubviews()
        self.update()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Secret")
        Analytics.shared.trackDidShowScreen(screenName: "secret")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.addActions()
        self.update()
    }

    private func addSubviews() {

        let (_, contentView) = Layout.scrollViewWithContentView(in: self)

        Layout.fillTop(of: contentView, with: self.textView)
        self.textView.constrainHeight(to: 175)

        Layout.fillSouth(of: self.textView, with: self.label)
    }

    private func update() {
        self.textView.contentOffset = CGPoint.zero
        self.navigationItem.rightBarButtonItem?.isEnabled = self.secret != nil
    }

    // MARK: Actions

    private func addActions() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: Localized.next.text,
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(nextButtonTouchUpInside))
    }

    @objc func nextButtonTouchUpInside() {
        guard let secret = self.secret else { return }
        let controller = AppConfigurationViewController(with: secret)
        self.navigationController?.pushViewController(controller, animated: true)
    }
}

extension SecretViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        self.secret = Secret(from: textView.text)
        textView.textColor = self.secret != nil ? .black : .red
        self.update()
    }
}
