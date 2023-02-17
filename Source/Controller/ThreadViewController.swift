//
//  ThreadViewController.swift
//  FBTT
//
//  Created by Christoph on 4/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting
import Combine

class ThreadViewController: ContentViewController {

    private let post: Message
    private var root: Message? {
        didSet {
            let key = root?.key ?? ""
            let identity = Bots.current.identity ?? ""
            draftKey = "com.planetary.ios.draft.reply." + key + identity
            draftStore = DraftStore(draftKey: draftKey)
        }
    }
    
    private lazy var dataSource: ThreadReplyPaginatedTableViewDataSource = {
        var dataSource = ThreadReplyPaginatedTableViewDataSource()
        dataSource.delegate = self
        return dataSource
    }()
    
    private let textViewDelegate = ThreadTextViewDelegate(font: UIFont.verse.reply,
                                                          color: UIColor.text.reply,
                                                          placeholderText: .postAReply,
                                                          placeholderColor: UIColor.text.placeholder)
    
    private var draftKey = ""
    private var draftStore = DraftStore(draftKey: "")
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private var cancellables = [AnyCancellable]()

    private var branchKey: Identifier {
        self.rootKey
    }

    private var rootKey: Identifier {
        self.root?.key ?? self.post.key
    }

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.contentInset = .bottom(20)
        view.dataSource = self.dataSource
        view.prefetchDataSource = self.dataSource
        view.delegate = self
        view.refreshControl = self.refreshControl
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    private lazy var interactionView: ThreadInteractionView = {
        let interactionView = ThreadInteractionView()
        interactionView.delegate = self
        interactionView.backgroundColor = .cardBackground
        return interactionView
    }()

    private lazy var rootPostView: PostCellView = {
        let view = PostCellView(message: self.root ?? self.post)
        view.displayHeader = false
        view.allowSpaceUnderGallery = false
        return view
    }()

    private lazy var topView: UIView = {
        let cellView = UIView.forAutoLayout()
        cellView.backgroundColor = .appBackground
        Layout.addSeparator(toTopOf: cellView)

        Layout.fillTop(of: cellView, with: self.rootPostView)
        Layout.fillBottom(of: cellView, with: self.interactionView)

        self.rootPostView.pinBottom(toTopOf: self.interactionView)

        return cellView
    }()

    private lazy var replyTextView: ReplyTextView = {
        let view = ReplyTextView(topSpacing: Layout.verticalSpacing, bottomSpacing: Layout.verticalSpacing)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(replyTextViewSwipeDown(gesture:)))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
        view.textViewDelegate = self.textViewDelegate
        Layout.addSeparator(toTopOf: view)
        view.backgroundColor = .cardBackground
        return view
    }()
    
    private lazy var menu: AboutsMenu = {
        let view = AboutsMenu()
        view.bottomSeparator.isHidden = true
        return view
    }()

    private let headerView = PostHeaderView(showTimestamp: true)
    
    // this view manages it's own height constraints
    // checkout ImageGallery.open() and close()
    private lazy var galleryView: ImageGalleryView = {
        let view = ImageGalleryView(height: 75)
        view.delegate = self
        view.backgroundColor = .cardBackground
        return view
    }()
    
    var images: [UIImage] {
        galleryView.images
    }

    private lazy var buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        view.minimize()
        view.topSeparator.isHidden = true
        view.photoButton.isHidden = false
        view.photoButton.addTarget(self, action: #selector(photoButtonTouchUpInside), for: .touchUpInside)
        view.postButton.setText(.postReply)
        view.postButton.action = didPressPostButton
        view.previewToggle.addTarget(self, action: #selector(didPressPreviewToggle), for: .valueChanged)
        view.backgroundColor = .cardBackground
        return view
    }()
    
    private let imagePicker = UIImagePicker()

    private var onNextUpdateScrollToPostWithMessageKey: Identifier?
    private var indexPathToScrollToOnKeyboardDidShow: IndexPath?
    private var replyTextViewBecomeFirstResponder = false

    init(with message: Message, startReplying: Bool = false) {
        assert(message.content.isPost)
        self.post = message
        self.onNextUpdateScrollToPostWithMessageKey = message.key
        // self.interactionView.postIdentifier = Identity
        super.init(scrollable: false)
        self.isKeyboardHandlingEnabled = true
        self.showsTabBarBorder = false
        self.addActions()
        self.replyTextViewBecomeFirstResponder = startReplying
        self.update(with: message)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Layout.fillTop(of: self.contentView, with: self.tableView)
        Layout.fillTop(of: self.contentView, with: self.menu)
        Layout.fillSouth(of: self.tableView, with: self.replyTextView)
        
        Layout.fillSouth(of: self.replyTextView, with: self.galleryView)
        
        Layout.fillBottom(of: self.contentView, with: self.buttonsView, respectSafeArea: false)

        self.buttonsView.pinTop(toBottomOf: self.galleryView)
        
        self.buttonsView.constrainHeight(to: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.load(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Post")
        Analytics.shared.trackDidShowScreen(screenName: "post")
        self.replyTextViewBecomeFirstResponderIfNecessary()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        headerView.removeFromSuperview()
        let textValue = AttributedString(replyTextView.attributedText)
        Task.detached(priority: .userInitiated) {
            await self.draftStore.save(text: textValue, images: self.images)
        }
    }

    private func load(animated: Bool = true, completion: (() -> Void)? = nil) {
        let post = self.post
        Bots.current.thread(message: post) { [weak self] root, replies, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.refreshControl.endRefreshing()
            if let error = error {
                self?.alert(error: error)
                completion?()
            } else {
                self?.update(with: root ?? post, replies: replies, animated: animated)
                completion?()
            }
        }
    }
    
    private func setUpDrafts() {
        Task {
            if let draft = await self.draftStore.loadDraft() {
                if let text = draft.attributedText {
                    replyTextView.attributedText = text
                }
                galleryView.add(draft.images)
                Log.info("Restored draft")
            }
            
            replyTextView
                .textPublisher
                .throttle(for: 3, scheduler: queue, latest: true)
                .sink { [weak self] newText in
                    let newTextValue = newText.map { AttributedString($0) }
                    Task(priority: .userInitiated) {
                        await self?.draftStore.save(text: newTextValue, images: self?.images ?? [])
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func refresh() {
        self.load()
    }

    private func update(with root: Message) {
        self.root = root

        self.headerView.update(with: root)
        self.addNavigationHeaderViewIfNeeded()

        self.rootPostView.update(with: root)
        self.tableView.tableHeaderView = self.topView
        self.tableView.tableHeaderView?.layoutIfNeeded()
        replyTextView.isHidden = root.offChain == true
    }

    private func update(with root: Message, replies: PaginatedMessageDataProxy, animated: Bool = true) {
        self.root = root

        self.headerView.update(with: root)
        self.addNavigationHeaderViewIfNeeded()

        self.rootPostView.update(with: root)
        self.tableView.tableHeaderView = self.topView
        self.tableView.tableHeaderView?.layoutIfNeeded()

        self.dataSource.update(source: replies)
        self.tableView.forceReload()
        self.scrollIfNecessary(animated: animated)
        self.interactionView.replyCount = replies.count
        self.interactionView.post = root
        self.interactionView.replies = replies as? StaticDataProxy
        self.interactionView.update()
        replyTextView.isHidden = root.offChain == true
        setUpDrafts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    // not sure why the tableHeaderView is not getting a proper width,
    // but we can constrain it to the superview once it exists.
    var tableHeaderWidthConstraint: NSLayoutConstraint?
    func sizeHeaderToFit() {
        if self.tableHeaderWidthConstraint == nil, let superview = self.topView.superview {
            self.tableHeaderWidthConstraint = self.topView.widthAnchor.constraint(equalTo: superview.widthAnchor)
            self.tableHeaderWidthConstraint?.isActive = true
        }
    }

    private func addNavigationHeaderViewIfNeeded() {
        guard headerView.superview == nil, let navBar = self.navigationController?.navigationBar else { return }

        let insets = UIEdgeInsets(top: 0, left: 48, bottom: 0, right: -Layout.horizontalSpacing)
        Layout.fill(view: navBar, with: self.headerView, insets: insets)
    }

    // MARK: Animations

    private func scrollIfNecessary(animated: Bool = true) {
        guard let key = self.onNextUpdateScrollToPostWithMessageKey else { return }
        self.onNextUpdateScrollToPostWithMessageKey = nil
        self.tableView.scroll(toMessageWith: key, animated: animated)
    }

    /// Scrolls to `indexPathToScrollToOnKeyboardDidShow` which is typically
    /// stored any time the table view is scrolled.  The optional delay is
    /// useful to stagger animations, just in case there is too much going
    /// on at one time.
    private func scrollToLastVisibleIndexPath(delay: TimeInterval = 0.25,
                                              animated: Bool = true) {
        guard let indexPath = self.indexPathToScrollToOnKeyboardDidShow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        }
    }

    // Forces the reply text view to be first responder if the controller
    // was inited to start replying immediately.
    private func replyTextViewBecomeFirstResponderIfNecessary() {

        // become first responder once then clear the flag
        guard self.replyTextViewBecomeFirstResponder else { return }
        self.replyTextViewBecomeFirstResponder = false
        self.replyTextView.becomeFirstResponder()

        self.buttonsView.maximize()
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()
    }

    // MARK: Actions

    private func addActions() {
        self.menu.didSelectAbout = { [unowned self] about in
            guard let range = self.textViewDelegate.mentionRange else { return }
            self.replyTextView.replaceText(in: range,
                                           with: about.mention,
                                           attributes: self.textViewDelegate.fontAttributes)
            self.textViewDelegate.clear()
            self.menu.hide()
        }
        
        self.textViewDelegate.didChangeMention = { [unowned self] string in
            self.menu.filter(by: string)
        }
        
        let buttonViewAnimationDuration: TimeInterval = 0.5
        
        self.textViewDelegate.didBeginEditing = { _ in
            self.buttonsView.maximize(duration: buttonViewAnimationDuration)
            self.scrollToLastVisibleIndexPath()
        }
        
        self.textViewDelegate.didEndEditing = { _ in
            self.buttonsView.minimize(duration: buttonViewAnimationDuration)
        }
    }

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load()
    }

    @objc private func replyTextViewSwipeDown(gesture: UISwipeGestureRecognizer) {
        guard gesture.direction == .down else { return }
        guard gesture.state == .ended else { return }
        self.replyTextView.resignFirstResponder()
    }

    func didPressPostButton(sender: AnyObject) {
        let text = self.replyTextView.attributedText
        guard text.length > 0 else { return }
        Analytics.shared.trackDidTapButton(buttonName: "reply")
        self.buttonsView.postButton.isEnabled = false
        
        AppController.shared.showProgress()
        
        let post = Post(attributedText: text, root: self.rootKey, branches: [self.branchKey])
        let images = self.galleryView.images
        let draftStore = draftStore
        let textValue = AttributedString(text)
        Task.detached(priority: .userInitiated) {
            await draftStore.save(text: textValue, images: images)
            do {
                let messageID = try await Bots.current.publish(post, with: images)
<<<<<<< Updated upstream
                Analytics.shared.trackDidReply()
=======
                Analytics.shared.trackDidReply(characterCount: post.text.count)
                await AppController.shared.hideProgress()
                await MainActor.run { self.buttonsView.postButton.isEnabled = true }
>>>>>>> Stashed changes
                await MainActor.run {
                    self.replyTextView.clear()
                    _ = self.replyTextView.resignFirstResponder()
                    self.buttonsView.minimize()
                    self.galleryView.removeAll()
                    self.galleryView.close()
                    self.onNextUpdateScrollToPostWithMessageKey = messageID
                    self.load()
                }
                await draftStore.clearDraft()
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await AppController.shared.hideProgress()
                await MainActor.run { self.buttonsView.postButton.isEnabled = true }
                await AppController.shared.alert(error: error)
            }
        }
    }
    
    @objc func didPressPreviewToggle() {
        Analytics.shared.trackDidTapButton(buttonName: "preview")
        self.replyTextView.previewActive = self.buttonsView.previewToggle.isOn
        self.buttonsView.maximize(duration: 0)
    }
    
    // MARK: Attaching photos
    
    @objc private func photoButtonTouchUpInside(sender: AnyObject) {
        
        Analytics.shared.trackDidTapButton(buttonName: "attach_photo")
        self.imagePicker.present(from: sender, controller: self) { [weak self] image in
            if let image = image { self?.galleryView.add(image) }
            self?.imagePicker.dismiss()
        }
    }

    // MARK: Notifications

    override func didBlockUser(notification: Notification) {
        guard let identity = notification.object as? Identity else { return }

        // if identity is root post author then pop off
        if self.root?.author == identity {
            self.navigationController?.remove(viewController: self)
        }

        // otherwise clean up data source
        else {
            self.tableView.deleteMessages(by: identity)
        }
    }
}

extension ThreadViewController: UITableViewDelegate {

    /// After scrolling, store the last visible row index path
    /// in case the keyboard will be shown.  This is to ensure
    /// that the table view adjusts so that it aligns a row
    /// with the top of the keyboard, and selects a row that
    /// was likely the one a human was reading.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.indexPathToScrollToOnKeyboardDidShow = self.tableView.indexPathForLastVisibleRow(percentVisible: 0.6)
    }
}

extension ThreadViewController: ThreadReplyPaginatedTableViewDataSourceDelegate {
    
    func threadReplyView(view: ThreadReplyView, didLoad message: Message) {
        view.tapGesture.tap = { [weak self] in
            self?.tableView.beginUpdates()
            view.toggleExpanded()
            self?.tableView.endUpdates()

            if view.textIsExpanded {
                self?.dataSource.expandedPosts.insert(message.key)
            } else {
                self?.dataSource.expandedPosts.remove(message.key)
            }
        }
    }
}

extension ThreadViewController: ThreadInteractionViewDelegate {
    
    func threadInteractionView(_ view: ThreadInteractionView, didLike post: Message) {
        let vote = ContentVote(link: self.rootKey,
                               value: 1,
                               expression: "💜",
                               root: self.rootKey,
                               branches: [self.branchKey])
        Bots.current.publish(content: vote) { [weak self] _, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.alert(error: error)
                } else {
                    self?.load(animated: true)
                }
            }
        }
    }
}

private class ThreadTextViewDelegate: MentionTextViewDelegate {

    // On each keystroke, checks if the text biew needs to be scrollable.
    // By default it is not so that it grows taller with each line.  But
    // once the max has been exceeded, the text view becomes scrollable.
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)

        if let replyTextView = textView.superview as? ReplyTextView {
            replyTextView.calculateHeight()
        }
    }
}

extension ThreadViewController: ImageGalleryViewDelegate {

    // Limits the max number of images to 8
    func imageGalleryViewDidChange(_ view: ImageGalleryView) {
        self.buttonsView.photoButton.isEnabled = view.images.count < 8
        view.images.isEmpty ? view.close() : view.open()
        let textValue = AttributedString(replyTextView.attributedText)
        Task.detached(priority: .userInitiated) {
            await self.draftStore.save(text: textValue, images: view.images)
        }
    }

    func imageGalleryView(_ view: ImageGalleryView, didSelect image: UIImage, at indexPath: IndexPath) {
        self.confirm(
            message: Localized.NewPost.confirmRemove.text,
            isDestructive: true,
            confirmTitle: Localized.NewPost.remove.text,
            confirmClosure: { view.remove(at: indexPath) }
        )
    }
}
