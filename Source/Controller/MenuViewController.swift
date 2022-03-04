//
//  MenuViewController.swift
//  FBTT
//
//  Created by Christoph on 7/31/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class MenuViewController: UIViewController, ConnectedPeerListRouter {
    
    var menuWidth: CGFloat = 300

    private lazy var menuView: MenuView = {
        let view = MenuView(frame: CGRect.zero, connectedPeersView: connectedPeersView)
        view.useAutoLayout()
        return view
    }()
    
    private var connectedPeersView: UIView {
        return connectedPeersViewController.view
    }
    
    private lazy var connectedPeersViewController: UIViewController = {
        let bot = Bots.current
        let viewModel = ConnectedPeerListCoordinator(
            bot: bot,
            statisticsService: BotStatisticsServiceAdaptor(bot: bot),
            router: self
        )
        return UIHostingController(rootView: ConnectedPeerListView(viewModel: viewModel))
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton.forAutoLayout()
        button.addTarget(self, action: #selector(closeButtonTouchUpInside), for: .touchUpInside)
        return button
    }()

    private let backgroundView: UIView = {
        let view = UIView.forAutoLayout()
        view.alpha = 0
        view.backgroundColor = UIColor.screenOverlay
        return view
    }()

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        self.addActions()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.backgroundView, respectSafeArea: false)

        view.addSubview(menuView)
        menuView.constrainTop(toTopOf: view)
        menuView.constrainLeading(to: view)
        menuView.constrainWidth(to: menuWidth)
        menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        addChild(connectedPeersViewController)
        connectedPeersViewController.didMove(toParent: self)

        view.addSubview(closeButton)
        closeButton.constrainTop(toTopOf: view)
        closeButton.constrainBottom(toBottomOf: view)
        closeButton.constrainTrailing(toTrailingOf: view)
        closeButton.constrainLeading(toTrailingOf: menuView, constant: 0)
        
        self.load()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Menu")
        Analytics.shared.trackDidShowScreen(screenName: "menu")
    }

    private func load() {
        guard let about = Bots.current.about else { return }
        self.menuView.profileView.update(with: about)
        self.menuView.label.text = about.nameOrIdentity
    }

    // MARK: Actions

    private func addActions() {
        self.menuView.profileView.imageView.isUserInteractionEnabled = true
        self.menuView.profileView.imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileViewTouchUpInside)))
        self.menuView.profileButton.addTarget(self, action: #selector(profileButtonTouchUpInside), for: .touchUpInside)
        self.menuView.settingsButton.addTarget(self, action: #selector(settingsButtonTouchUpInside), for: .touchUpInside)
        self.menuView.helpButton.addTarget(self, action: #selector(helpButtonTouchUpInside), for: .touchUpInside)
        self.menuView.reportBugButton.addTarget(self, action: #selector(reportBugButtonTouchUpInside), for: .touchUpInside)
    }

    @objc private func closeButtonTouchUpInside() {
        self.close()
    }

    @objc private func profileViewTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "profile")
        guard let identity = Bots.current.identity else { return }
        AppController.shared.pushViewController(for: .about, with: identity)
        self.close()
    }
    
    @objc private func profileButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "your_profile")
        guard let identity = Bots.current.identity else { return }
        AppController.shared.pushViewController(for: .about, with: identity)
        self.close()
    }

    @objc private func settingsButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "settings")
        self.close() {
            AppController.shared.showSettingsViewController()
        }
    }

    @objc private func helpButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "support")
        guard let controller = Support.shared.mainViewController() else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return
        }
        self.close() {
            AppController.shared.push(controller)
        }
    }

    @objc private func reportBugButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "report_bug")
        guard let controller = Support.shared.myTicketsViewController(from: Bots.current.identity) else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return
        }
        self.close() {
            AppController.shared.push(controller)
        }
    }

    // MARK: Animations

    func open(animated: Bool = true) {
        self.view.layoutSubviews()
        // For some reason using `.transform` here breaks touches in the SwiftUI view so I'm using `.frame` instead.
        menuView.frame.origin.x = menuView.frame.origin.x - menuWidth
        UIView.animate(withDuration: animated ? 0.2 : 0,
                       delay: 0,
                       options: .curveEaseOut,
                       animations:
            {
                self.backgroundView.alpha = 1
                self.menuView.frame.origin.x = 0
            },
                       completion: nil)
    }

    func close(animated: Bool = true, completion: (() -> Void)? = nil) {

        UIView.animate(withDuration: animated ? 0.2 : 0,
                       delay: 0,
                       options: .curveEaseIn,
                       animations:
            {
                self.backgroundView.alpha = 0
                self.menuView.transform = CGAffineTransform(translationX: -self.menuWidth, y: 0)
            },
                       completion:
            {
                finished in
                self.dismiss(animated: false) { completion?() }
            })
    }
    
    // MARK: - ConnectedPeerListRouter
    func showProfile(for identity: Identity) {
        AppController.shared.pushViewController(for: .about, with: identity)
        close()
    }
}

fileprivate class MenuView: UIView {

    let profileView = ProfileImageView()

    let label: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        view.textAlignment = .center
        view.textColor = UIColor.text.default
        view.lineBreakMode = .byTruncatingTail
        return view
    }()

    let profileButton = MenuButton(title: .yourProfile, image: UIImage.verse.profile)
    let settingsButton = MenuButton(title: .settings, image: UIImage.verse.settings)
    let helpButton = MenuButton(title: .helpAndSupport, image: UIImage.verse.help)
    let reportBugButton = MenuButton(title: .reportBug, image: UIImage.verse.reportBug)

    init(frame: CGRect, connectedPeersView: UIView) {

        super.init(frame: frame)
        self.backgroundColor = UIColor.menuBackgroundColor

        let stackView = UIStackView().useAutoLayout()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        self.addSubview(stackView)
        stackView.constrain(to: self)
        
        stackView.addArrangedSubview(buildProfileContainerView())
        stackView.addArrangedSubview(buildMenuButtonsContainerView())
        
        connectedPeersView.useAutoLayout()
        connectedPeersView.backgroundColor = .clear
        stackView.addArrangedSubview(connectedPeersView)
        let maxHeightConstraint = connectedPeersView.heightAnchor.constraint(equalToConstant: 310)
        maxHeightConstraint.priority = UILayoutPriority(501)
        maxHeightConstraint.isActive = true

        if Date.todayIsAHoliday() {
            Layout.fill(view: self, with: SnowView(), respectSafeArea: false)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Builds the view that holds the user's profile pic and name. Not idempotent.
    private func buildProfileContainerView() -> UIView {
        let profileContainer = UIView.forAutoLayout()
        profileContainer.addSubview(profileView)
        profileContainer.heightAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
        profileView.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor).isActive = true
        profileView.constrainSize(to: CGSize(width: 96, height: 96))
        profileView.pinTopToSuperview(constant: 30)

        Layout.fillSouth(of: profileView, with: label, insets: UIEdgeInsets(top: 20, left: Layout.horizontalSpacing, bottom: 0, right: -Layout.horizontalSpacing))
        label.constrainBottom(toBottomOf: profileContainer, constant: -20)
        
        return profileContainer
    }
    
    /// Builds the view that holds the menu buttons. Not idempotent.
    private func buildMenuButtonsContainerView() -> UIView {
        let menuButtonContainer = UIView.forAutoLayout()
        
        var separator = Layout.separatorView(color: UIColor.menuBorderColor)
        menuButtonContainer.addSubview(separator)
        separator.constrainTop(toTopOf: menuButtonContainer)
        separator.constrainLeadingToSuperview()
        separator.constrainTrailingToSuperview()

        Layout.fillSouth(of: separator, with: self.profileButton)
        self.profileButton.constrainHeight(to: 50)
        self.profileButton.imageEdgeInsets = .top(-5)
        
        separator = Layout.separatorView(color: UIColor.menuBorderColor)
        Layout.fillSouth(of: self.profileButton, with: separator)

        Layout.fillSouth(of: separator, with: self.settingsButton)
        self.settingsButton.constrainHeight(to: 50)
        
        separator = Layout.separatorView(color: UIColor.menuBorderColor)
        Layout.fillSouth(of: self.settingsButton, with: separator)

        Layout.fillSouth(of: separator, with: self.helpButton)
        self.helpButton.constrainHeight(to: 50)
        self.helpButton.imageEdgeInsets = .top(2)
        
        separator = Layout.separatorView(color: UIColor.menuBorderColor)
        Layout.fillSouth(of: self.helpButton, with: separator)

        Layout.fillSouth(of: separator, with: self.reportBugButton)
        self.reportBugButton.constrainHeight(to: 50)
        
        separator = Layout.separatorView(color: UIColor.menuBorderColor)
        Layout.fillSouth(of: self.reportBugButton, with: separator)
        
        separator = Layout.separatorView(color: UIColor.menuBorderColor)
        Layout.fillSouth(of: reportBugButton, with: separator)

        separator.bottomAnchor.constraint(equalTo: menuButtonContainer.bottomAnchor).isActive = true
        
        return menuButtonContainer
    }
}

fileprivate class ProfileImageView: UIView {

    let circleView: UIView = {
        let view = UIView.forAutoLayout()
        view.stroke(color: .avatarRing)
        return view
    }()

    let imageView = AvatarImageView()

    convenience init() {
        self.init(frame: .zero)
        self.useAutoLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        Layout.fill(view: self, with: self.circleView, insets: .zero)
        let spacing: CGFloat = 7
        Layout.fill(view: self, with: self.imageView, insets: UIEdgeInsets(top: spacing, left: spacing, bottom: -spacing, right: -spacing))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.circleView.round()
    }

    func update(with about: About) {
        self.imageView.set(image: about.image)
    }
}

fileprivate class MenuButton: UIButton {

    init(title: Text, image: UIImage? = nil) {

        super.init(frame: .zero)
        self.contentHorizontalAlignment = .left
        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 26, bottom: 0, right: 0)
        self.titleEdgeInsets = UIEdgeInsets(top: 0, left: 19, bottom: 0, right: 0)

        self.setTitle(title.text, for: .normal)
        self.setTitleColor(UIColor.menuUnselectedItemText, for: .normal)
        self.setTitleColor(UIColor.menuSelectedItemText, for: .highlighted)
        
        self.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)

        self.setImage(image, for: .normal)

        self.setBackgroundImage(UIColor.menuSelectedItemBackground.image(), for: .highlighted)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
