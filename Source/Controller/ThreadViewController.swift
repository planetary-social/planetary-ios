//
//  ThreadViewController.swift
//  FBTT
//
//  Created by Christoph on 4/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class ThreadViewController: ContentViewController {

    private let post: KeyValue
    private var root: KeyValue?
    
    private lazy var dataSource: ThreadReplyPaginatedTableViewDataSource = {
        var dataSource = ThreadReplyPaginatedTableViewDataSource()
        dataSource.delegate = self
        return dataSource
    }()
    
    private let textViewDelegate = ThreadTextViewDelegate(font: UIFont.verse.reply,
                                                          color: UIColor.text.reply,
                                                          placeholderText: .postAReply,
                                                          placeholderColor: UIColor.text.placeholder)

    private var branchKey: Identifier {
        return self.rootKey
    }

    private var rootKey: Identifier {
        return self.root?.key ?? self.post.key
    }

    private lazy var menu: AboutsMenu = {
        let view = AboutsMenu()
        view.topSeparator.isHidden = true
        return view
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.contentInset = .bottom(10)
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

    private var interactionView = ThreadInteractionView()

    private lazy var rootPostView: PostCellView = {
        let view = PostCellView(keyValue: self.root ?? self.post)
        view.displayHeader = false
        view.allowSpaceUnderGallery = false
        return view
    }()

    private lazy var topView: UIView = {
        let cellView = UIView.forAutoLayout()
        cellView.backgroundColor = UIColor.background.default
        Layout.addSeparator(toTopOf: cellView)

        Layout.fillTop(of: cellView, with: self.rootPostView)
        Layout.fillBottom(of: cellView, with: self.interactionView)

        self.rootPostView.pinBottom(toTopOf: self.interactionView)

        return cellView
    }()

    private lazy var replyTextView: ReplyTextView = {
        let view = ReplyTextView(topSpacing: Layout.verticalSpacing, bottomSpacing: 0)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(replyTextViewSwipeDown(gesture:)))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
        view.textViewDelegate = self.textViewDelegate
        Layout.addSeparator(toTopOf: view)
        return view
    }()

    private let headerView = PostHeaderView()

    private lazy var buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        view.minimize()
        view.topSeparator.isHidden = true
        view.photoButton.isHidden = true
        view.postButton.setText(.postReply)
        view.postButton.action = didPressPostButton
        return view
    }()

    private var onNextUpdateScrollToPostWithKeyValueKey: Identifier?
    private var indexPathToScrollToOnKeyboardDidShow: IndexPath?
    private var replyTextViewBecomeFirstResponder = false

    init(with keyValue: KeyValue, startReplying: Bool = false) {
        assert(keyValue.value.content.isPost)
        self.post = keyValue
        self.onNextUpdateScrollToPostWithKeyValueKey = keyValue.key
        //self.interactionView.postIdentifier = Identity
        super.init(scrollable: false)
        self.isKeyboardHandlingEnabled = true
        self.showsTabBarBorder = false
        self.addActions()
        self.replyTextViewBecomeFirstResponder = startReplying
        self.update(with: keyValue)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Layout.fillTop(of: self.contentView, with: self.tableView)
        Layout.fillTop(of: self.contentView, with: self.menu)
        Layout.fillSouth(of: self.tableView, with: self.replyTextView)
        Layout.fillSouth(of: self.replyTextView, with: self.buttonsView)

        self.buttonsView.pinBottomToSuperviewBottom(constant: 0, respectSafeArea: false)
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
    }

    private func load(animated: Bool = true) {
        let post = self.post
        Bots.current.thread(keyValue: post) { [weak self] root, replies, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.refreshControl.endRefreshing()
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: root ?? post, replies: replies, animated: animated)
            }
        }
    }

    private func refresh() {
        self.load()
    }

    private func update(with root: KeyValue) {
        self.root = root

        self.headerView.update(with: root)
        self.addNavigationHeaderViewIfNeeded()

        self.rootPostView.update(with: root)
        self.tableView.tableHeaderView = self.topView
        self.tableView.tableHeaderView?.layoutIfNeeded()
    }

    private func update(with root: KeyValue, replies: PaginatedKeyValueDataProxy, animated: Bool = true) {
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
        guard let key = self.onNextUpdateScrollToPostWithKeyValueKey else { return }
        self.onNextUpdateScrollToPostWithKeyValueKey = nil
        self.tableView.scroll(toKeyValueWith: key, animated: animated)
    }

    /// Scrolls to `indexPathToScrollToOnKeyboardDidShow` which is typically
    /// stored any time the table view is scrolled.  The optional delay is
    /// useful to stagger animations, just in case there is too much going
    /// on at one time.
    private func scrollToLastVisibleIndexPath(delay: TimeInterval = 0.25,
                                              animated: Bool = true)
    {
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
        self.replyTextView.textView.becomeFirstResponder()

        self.buttonsView.maximize()
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()
    }

    // MARK: Actions

    private func addActions() {

        self.menu.didSelectAbout = {
            [unowned self] about in
            guard let range = self.textViewDelegate.mentionRange else { return }
            self.replyTextView.textView.replaceText(in: range,
                                                with: about.mention,
                                                attributes: self.textViewDelegate.fontAttributes)
            self.textViewDelegate.clear()
            self.menu.hide()
        }

        self.textViewDelegate.didChangeMention = {
            [unowned self] string in
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

    func didPressPostButton() {
        guard let text = self.replyTextView.textView.attributedText, text.length > 0 else { return }
        Analytics.shared.trackDidTapButton(buttonName: "reply")
        let post = Post(attributedText: text, root: self.rootKey, branches: [self.branchKey])
        AppController.shared.showProgress()
        Bots.current.publish(post) { [weak self] key, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            AppController.shared.hideProgress()
            if let error = error {
                self?.alert(error: error)
            } else {
                Analytics.shared.trackDidReply()
                self?.replyTextView.clear()
                self?.replyTextView.resignFirstResponder()
                self?.onNextUpdateScrollToPostWithKeyValueKey = key
                self?.load()
            }
        }
    }

    // MARK: Notifications

    override func didBlockUser(notification: NSNotification) {
        guard let identity = notification.object as? Identity else { return }

        // if identity is root post author then pop off
        if self.root?.value.author == identity {
            self.navigationController?.remove(viewController: self)
        }

        // otherwise clean up data source
        else {
            self.tableView.deleteKeyValues(by: identity)
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
    
    func threadReplyView(view: ThreadReplyView, didLoad keyValue: KeyValue) {
        view.tapGesture.tap = { [weak self] in
            self?.tableView.beginUpdates()
            view.toggleExpanded()
            self?.tableView.endUpdates()

            if view.textIsExpanded {
                self?.dataSource.expandedPosts.insert(keyValue.key)
            } else {
                self?.dataSource.expandedPosts.remove(keyValue.key)
            }
        }
    }
}


fileprivate class ThreadTextViewDelegate: MentionTextViewDelegate {

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
