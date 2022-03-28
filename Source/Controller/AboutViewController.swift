//
//  AboutViewController.swift
//  FBTT
//
//  Created by Christoph on 2/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting
import Support

class AboutViewController: ContentViewController {

    private let identity: Identity
    private var about: About?

    private let aboutView = AboutView()

    private lazy var dataSource: PostReplyPaginatedDataSource = {
        let dataSource = PostReplyPaginatedDataSource()
        dataSource.delegate = self
        return dataSource
    }()
    
    private lazy var delegate = PostReplyPaginatedDelegate(on: self)

    private var followings: [About] = []
    private var followers: [About] = []

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.dataSource
        view.backgroundColor = .appBackground
        return view
    }()
    
    private var optionsIcon: UIBarButtonItem?

    // TODO https://app.asana.com/0/914798787098068/1146899678085073/f
    // TODO improve init delegation
    init(with identity: Identity) {
        self.identity = identity
        let about = About(about: identity)
        self.about = about
        super.init(scrollable: false)
        self.aboutView.update(with: about)
        self.addActions()
    }

    convenience init(with about: About) {
        self.init(with: about.identity)
        self.update(with: about)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.contentView, with: self.tableView, respectSafeArea: false)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.verse.optionsOff,
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(didPressOptionsIcon))
        self.navigationItem.rightBarButtonItem?.tintColor = .secondaryAction
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show About")
        Analytics.shared.trackDidShowScreen(screenName: "about")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.loadAbout()
        self.loadFeed()
        self.loadFollows()
        self.loadFollowedBy()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.tableView.setTableHeaderView(self.aboutView)
    }

    private func loadAbout() {
        Bots.current.about(identity: self.identity) {
            [weak self] about, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            guard let about = about else { return }
            self?.about = about
            self?.update(with: about)
        }
    }

    private func loadFeed() {
        Bots.current.feed(identity: self.identity) {
            [weak self] src, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            guard error == nil else {
                return
            }
            self?.dataSource.update(source: src)
            self?.tableView.forceReload()
        }
    }

    private func loadFollows() {
        Bots.current.followings(identity: self.identity) { [weak self] (abouts: [About], error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.followings = abouts
            self?.updateFollows()
        }
    }

    private func loadFollowedBy() {
        Bots.current.followers(identity: self.identity) { [weak self] (abouts: [About], error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.followers = abouts
            self?.updateFollows()
        }
    }

    // MARK: Updates

    private func update(with about: About) {
        self.about = about
        self.navigationItem.title = about.name
        self.aboutView.update(with: about)
    }

    func update(with person: Person) {
        self.navigationItem.title = person.name
        self.aboutView.update(with: person)
    }

    private func updateFollows() {
        self.aboutView.update(followedBy: followers, following: followings)
    }

    // MARK: Actions

    private let imagePicker = ImagePicker()

    private func addActions() {
        self.aboutView.editButton.action = self.didPressEdit
        self.aboutView.shareButton.action = self.didPressShare
        self.aboutView.followingView.action = self.didTapFollowing
        self.aboutView.followedByView.action = self.didTapFollowedBy

        self.aboutView.editPhotoButton.addTarget(self,
                                                 action: #selector(editPhotoButtonTouchUpInside),
                                                 for: .touchUpInside)

        self.aboutView.followButton.onUpdate = {
            _ in

            self.loadFollowedBy()

            if let about = self.about {
                self.update(with: about)
            }
        }
    }

    @objc private func editPhotoButtonTouchUpInside(sender: AnyObject) {
        
        Analytics.shared.trackDidTapButton(buttonName: "update_avatar")
        self.imagePicker.present(from: sender, openCameraInSelfieMode: true) {
            [unowned self] image in
            guard let uiimage = image else {
                return
            }
            self.publishProfilePhoto(uiimage) { [weak self] in
                self?.imagePicker.dismiss()
            }
        }
    }

    @objc private func didPressOptionsIcon(sender: AnyObject) {
        Analytics.shared.trackDidTapButton(buttonName: "options")
        
        var actions = [UIAlertAction]()

        let sharePublicIdentifier = UIAlertAction(title: Text.sharePublicIdentifier.text, style: .default) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "share_public_identifier")

            let activityController = UIActivityViewController(activityItems: [self.identity],
                                                              applicationActivities: nil)
            activityController.configurePopover(from: sender)
            self.present(activityController, animated: true)
        }
        actions.append(sharePublicIdentifier)

        if let publicLink = self.identity.publicLink {
            let share = UIAlertAction(title: Text.shareThisProfile.text, style: .default) { _ in
                Analytics.shared.trackDidSelectAction(actionName: "share_profile")

                let who = self.about?.name ?? self.identity
                let text = Text.shareThisProfileText.text(["who": who,
                                                           "link": publicLink.absoluteString])
                
                let activityController = UIActivityViewController(activityItems: [text],
                                                                  applicationActivities: nil)
                activityController.configurePopover(from: sender)
                self.present(activityController, animated: true)
            }
            actions.append(share)
        }

        if !identity.isCurrentUser {
            let block = UIAlertAction(title: Text.blockUser.text,
                                      style: .destructive,
                                      handler: self.didSelectBlockAction(action:))
            actions.append(block)

            let report = UIAlertAction(title: Text.reportUser.text,
                                       style: .destructive,
                                       handler: self.didSelectReportAction(action:))
            actions.append(report)
        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }
        actions.append(cancel)

        AppController.shared.choose(from: actions, sourceView: sender)
    }

    private func publishProfilePhoto(_ uiimage: UIImage, completionHandler: @escaping () -> Void) {
        // AppController.shared.showProgress()

        Bots.current.addBlob(jpegOf: uiimage, largestDimension: 1_000) { [weak self] image, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                AppController.shared.hideProgress()
                self?.alert(error: error)
            } else {
                guard let about = self?.about?.mutatedCopy(image: image) else {
                    // I don't see why this should ever happen
                    // But will leave as it is
                    let error = AppError.unexpected
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    AppController.shared.hideProgress()
                    return
                }
                Bots.current.publish(content: about) { _, error in
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    if let error = error {
                        AppController.shared.hideProgress()
                        self?.alert(error: error)
                    } else {
                        Analytics.shared.trackDidUpdateAvatar()
                        Bots.current.about { (newAbout, error) in
                            Log.optional(error)
                            CrashReporting.shared.reportIfNeeded(error: error)
                            
                            AppController.shared.hideProgress()
                            
                            if let newAbout = newAbout {
                                NotificationCenter.default.post(Notification.didUpdateAbout(newAbout))
                            }
                            
                            self?.aboutView.imageView.fade(to: uiimage)
                            completionHandler()
                        }
                    }
                }
            }
        }
    }

    private func didPressEdit(sender: AnyObject) {
        Analytics.shared.trackDidTapButton(buttonName: "update_profile")
        
        guard let about = self.about else { return }
        let controller = EditAboutViewController(with: about)
        controller.saveCompletion = {
            [weak self] _ in
            // AppController.shared.showProgress()
            Bots.current.publish(content: controller.about) { [weak self] (_, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                if let error = error {
                    AppController.shared.hideProgress()
                    self?.alert(error: error)
                } else {
                    Analytics.shared.trackDidUpdateProfile()
                    Bots.current.about { (newAbout, error) in
                        Log.optional(error)
                        CrashReporting.shared.reportIfNeeded(error: error)
                        AppController.shared.hideProgress()
                        if let newAbout = newAbout {
                            NotificationCenter.default.post(Notification.didUpdateAbout(newAbout))
                            self?.update(with: controller.about)
                        }
                        self?.dismiss(animated: true)
                    }
                }
            }
        }
        let feature = FeatureViewController(rootViewController: controller)
        self.navigationController?.present(feature, animated: true, completion: nil)
    }

    private func didPressShare(sender: AnyObject) {
        Analytics.shared.trackDidTapButton(buttonName: "share")

        var actions = [UIAlertAction]()

        let sharePublicIdentifier = UIAlertAction(title: Text.sharePublicIdentifier.text, style: .default) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "share_public_identifier")

            let activityController = UIActivityViewController(activityItems: [self.identity],
                                                              applicationActivities: nil)
            activityController.configurePopover(from: sender)
            self.present(activityController, animated: true)
        }
        actions.append(sharePublicIdentifier)

        if let publicLink = self.identity.publicLink {
            let sharePublicLink = UIAlertAction(title: Text.shareThisProfile.text, style: .default) { _ in
                Analytics.shared.trackDidSelectAction(actionName: "share_profile")

                let who = self.about?.name ?? self.identity
                let text = Text.shareThisProfileText.text(["who": who,
                                                           "link": publicLink.absoluteString])

                let activityController = UIActivityViewController(activityItems: [text],
                                                                  applicationActivities: nil)
                activityController.configurePopover(from: sender)
                self.present(activityController, animated: true)
            }
            actions.append(sharePublicLink)
        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }
        actions.append(cancel)

        AppController.shared.choose(from: actions, sourceView: sender)
    }

    private func didTapFollowing() {
        Analytics.shared.trackDidTapButton(buttonName: "following")
        let controller = FollowingTableViewController(identity: self.identity, followings: self.followings)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func didTapFollowedBy() {
        Analytics.shared.trackDidTapButton(buttonName: "followed_by")
        let controller = FollowerTableViewController(identity: self.identity, followers: self.followers)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func didSelectBlockAction(action: UIAlertAction) {
        Analytics.shared.trackDidSelectAction(actionName: "block_identity")
        AppController.shared.promptToBlock(identity, name: self.about?.name)
    }

    private func didSelectReportAction(action: UIAlertAction) {
        guard let about = self.about, let name = about.name, let me = Bots.current.identity else {
            return
        }
        Analytics.shared.trackDidSelectAction(actionName: "report_user")
        guard let controller = Support.shared.newTicketViewController(from: me,
                                                                      reporting: about.identity,
                                                                      name: name) else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }

    // MARK: Notifications

    override func didBlockUser(notification: NSNotification) {
        guard let identity = notification.object as? Identity else { return }
        guard identity == self.identity else { return }
        self.navigationController?.remove(viewController: self)
    }
}

private class AboutPostView: KeyValueView {

    lazy var view = PostCellView()

    convenience init() {
        self.init(frame: .zero)
        self.tapGesture = self.view.tapGesture
        let separator = Layout.addSeparator(toTopOf: self, height: 10, color: .appBackground)
        Layout.addSeparator(toBottomOf: separator)
        Layout.fill(view: self,
                    with: self.view,
                    insets: UIEdgeInsets.top(10))
        self.view.pinBottomToSuperviewBottom()
        Layout.addSeparator(toBottomOf: self)
    }

    override func update(with keyValue: KeyValue) {
        self.view.update(with: keyValue)
    }
}

extension AboutViewController: PostReplyPaginatedDataSourceDelegate {
    
    func postReplyView(view: PostReplyView, didLoad keyValue: KeyValue) {
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: keyValue)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue, startReplying: true)
        }
    }
    
    private func pushThreadViewController(with keyValue: KeyValue, startReplying: Bool = false) {
        let controller = ThreadViewController(with: keyValue, startReplying: startReplying)
        self.navigationController?.pushViewController(controller, animated: true)
    }
}
