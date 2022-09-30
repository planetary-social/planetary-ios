//
//  HomeViewController.swift
//  FBTT
//
//  Created by Christoph on 2/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class HomeViewController: ContentViewController, HelpDrawerHost {

    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(newPostButtonTouchUpInside)
        )
        return item
    }()
    
    lazy var helpButton: UIBarButtonItem = { HelpDrawerCoordinator.helpBarButton(for: self) }()
    var helpDrawerType: HelpDrawer { .home }

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    private lazy var dataSource: PostReplyPaginatedDataSource = {
        let dataSource = PostReplyPaginatedDataSource()
        dataSource.delegate = self
        return dataSource
    }()
    
    private lazy var delegate = PostReplyPaginatedDelegate(on: self)
    
    private lazy var floatingRefreshButton: FloatingRefreshButton = {
        let button = FloatingRefreshButton()
        button.addTarget(
            self,
            action: #selector(floatingRefreshButtonDidTouchUpInside(button:)),
            for: .touchUpInside
        )
        return button
    }()

    /// The last time we loaded the feed from the database or we checked if there are new items to show
    private var lastTimeNewFeedUpdatesWasChecked = Date()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.dataSource
        view.refreshControl = self.refreshControl
        view.sectionHeaderHeight = 0
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        view.accessibilityIdentifier = "FeedTableView"
        view.cellLayoutMarginsFollowReadableWidth = true
        return view
    }()
    
    private lazy var emptyView: UIView = {
        let view = UIView()
        
        let imageView = UIImageView(image: UIImage(imageLiteralResourceName: "icon-planetary"))
        Layout.centerHorizontally(imageView, in: view)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50)
        ])
        
        let titleLabel = UILabel.forAutoLayout()
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.systemFont(ofSize: 25, weight: .medium)
        titleLabel.text = "Welcome!\nThis is your feed"
        titleLabel.textColor = UIColor.text.default
        titleLabel.textAlignment = .center
        Layout.centerHorizontally(titleLabel, in: view)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
        ])
        
        let detailLabel = UILabel.forAutoLayout()
        detailLabel.numberOfLines = 0
        detailLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        detailLabel.text = Text.emptyHomeFeedMessage.text
        detailLabel.textColor = UIColor.text.default
        detailLabel.textAlignment = .center
        view.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            detailLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 60),
            detailLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -60)
        ])
        
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self, action: #selector(directoryButtonTouchUpInside), for: .touchUpInside)
        let image = UIColor.tint.default.image().resizableImage(withCapInsets: .zero)
        button.setBackgroundImage(image, for: .normal)
        button.setTitle(Text.goToYourNetwork.text, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.contentEdgeInsets = .pillButton
        button.roundedCorners(radius: 20)
        button.constrainHeight(to: 40)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            button.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 60),
            button.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -60)
        ])
        
        return view
    }()

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .home)
        navigationItem.rightBarButtonItems = [newPostBarButtonItem, helpButton]
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }
    
    override init(scrollable: Bool = true, title: Text? = nil, dynamicTitle: String? = nil) {
        super.init(scrollable: scrollable, title: title, dynamicTitle: dynamicTitle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        
        self.floatingRefreshButton.layout(in: self.view, below: self.tableView)
        
        self.addLoadingAnimation()
        self.load()
        
        self.registerDidRefresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeHomeFeedAlgorithm(notification:)),
            name: .didChangeHomeFeedAlgorithm,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Home")
        Analytics.shared.trackDidShowScreen(screenName: "home")
        HelpDrawerCoordinator.showFirstTimeHelp(for: self)
    }

    // MARK: Load and refresh
    
    func load(animated: Bool = false) {
        Bots.current.recent { [weak self] proxy, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.refreshControl.endRefreshing()
            self?.removeLoadingAnimation()
            self?.floatingRefreshButton.hide()
            AppController.shared.hideProgress()
             
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: proxy, animated: animated)
            }
        }
    }
    
    private func update(with proxy: PaginatedMessageDataProxy, animated: Bool) {
        if proxy.count == 0 {
            self.tableView.backgroundView = self.emptyView
        } else {
            self.emptyView.removeFromSuperview()
            self.tableView.backgroundView = nil
        }
        lastTimeNewFeedUpdatesWasChecked = Date()
        self.dataSource.update(source: proxy)
        self.tableView.reloadData()
        self.navigationController?.tabBarItem?.badgeValue = nil
        let shouldScrollToTop = proxy.count > 0
        if shouldScrollToTop {
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    // MARK: Actions

    @objc
    func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load()
    }
    
    @objc
    func floatingRefreshButtonDidTouchUpInside(button: FloatingRefreshButton) {
        button.hide()
        self.refreshControl.beginRefreshing()
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl.frame.height), animated: false)
        self.load(animated: true)
    }

    @objc
    func newPostButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "compose")
        let controller = NewPostViewController()
        controller.didPublish = { [weak self] _ in
            self?.load()
        }
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }
    
    @objc
    func directoryButtonTouchUpInside() {
        guard let homeViewController = self.parent?.parent as? MainViewController else {
            return
        }
        homeViewController.selectDirectoryTab()
    }

    // MARK: Notifications

    override func didBlockUser(notification: Notification) {
        guard let identity = notification.object as? Identity else { return }
        self.tableView.deleteMessages(by: identity)
    }
    
    override func didRefresh(notification: Notification) {
        // Check that more than a minute passed since the last time we checked for new updates
        let elapsed = Date().timeIntervalSince(lastTimeNewFeedUpdatesWasChecked)
        guard elapsed > 60 else {
            return
        }
        let currentProxy = self.dataSource.data
        let currentKeyAtTop = currentProxy.messageBy(index: 0)?.key
        if let message = currentKeyAtTop {
            let operation = NumberOfRecentItemsOperation(lastMessage: message)
            operation.completionBlock = { [weak self] in
                self?.lastTimeNewFeedUpdatesWasChecked = Date()
                let numberOfNewItems = operation.numberOfRecentItems
                if numberOfNewItems > 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.navigationController?.tabBarItem?.badgeValue = "\(numberOfNewItems)"
                        let shouldAnimate = self?.navigationController?.topViewController == self
                        self?.floatingRefreshButton.setTitle(with: numberOfNewItems)
                        self?.floatingRefreshButton.show(animated: shouldAnimate)
                    }
                }
            }
            AppController.shared.operationQueue.addOperation(operation)
        }
    }
    
    @objc
    func didChangeHomeFeedAlgorithm(notification: Notification) {
        load(animated: true)
    }
}

extension HomeViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

extension HomeViewController: PostReplyPaginatedDataSourceDelegate {
    
    func postReplyView(view: PostReplyView, didLoad message: Message) {
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: message)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: message)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: message, startReplying: true)
        }
    }
    
    private func pushThreadViewController(with message: Message, startReplying: Bool = false) {
        let controller = ThreadViewController(with: message, startReplying: startReplying)
        self.navigationController?.pushViewController(controller, animated: true)
    }
}
