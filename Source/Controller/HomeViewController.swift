//
//  HomeViewController.swift
//  FBTT
//
//  Created by Christoph on 2/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class HomeViewController: ContentViewController {

    private static var refreshBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(newPostButtonTouchUpInside))
        return item
    }()

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
    
    private lazy var floatingRefreshButton: UIButton = {
        let button = UIButton.forAutoLayout()
        let titleAttributes = [NSAttributedString.Key.font: UIFont.verse.floatingRefresh,
                               NSAttributedString.Key.foregroundColor: UIColor.white]
        let attributedTitle = NSAttributedString(string: "REFRESH", attributes: titleAttributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.backgroundColor = UIColor.tint.default
        button.contentEdgeInsets = .floatingRefreshButton
        button.addTarget(self,
                         action: #selector(floatingRefreshButtonDidTouchUpInside(button:)),
                         for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.dataSource
        view.refreshControl = self.refreshControl
        view.sectionHeaderHeight = 0
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
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
        detailLabel.text = "And it is rather bare! Have you considered following a few users or topics?\n\nSearch the directory for existing users or invite the people you want to follow. "
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
        button.setTitle("Go to Directory", for: .normal)
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
        let imageView = UIImageView(image: UIImage(named: "title"))
        imageView.contentMode = .scaleAspectFit
        let view = UIView.forAutoLayout()
        Layout.fill(view: view, with: imageView, respectSafeArea: false)
        self.navigationItem.titleView = view
        self.navigationItem.rightBarButtonItems = [self.newPostBarButtonItem]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(scrollable: Bool = true, title: Text? = nil, dynamicTitle: String? = nil) {
        super.init(scrollable: scrollable, title: title, dynamicTitle: dynamicTitle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        
        Layout.centerHorizontally(self.floatingRefreshButton, in: self.view)
        self.floatingRefreshButton.constrainHeight(to: 32)
        self.floatingRefreshButton.roundedCorners(radius: 16)
        self.floatingRefreshButton.constrainTop(toTopOf: self.tableView, constant: 8)
        
        self.addLoadingAnimation()
        self.load()
        self.showLogoutNoticeIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Home")
        Analytics.trackDidShowScreen(screenName: "home")
    }

    // MARK: Load and refresh
    
    func load(animated: Bool = false) {
        Bots.current.recent() { [weak self] proxy, error in
            Log.optional(error)
            self?.refreshControl.endRefreshing()
            self?.removeLoadingAnimation()
            AppController.shared.hideProgress()
             
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: proxy, animated: animated)
            }
        }
    }
    
    func refreshAndLoad(animated: Bool = false) {
        if HomeViewController.refreshBackgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(HomeViewController.refreshBackgroundTaskIdentifier)
        }
        
        Log.info("Pull down to refresh triggering a medium refresh")
        let refreshOperation = RefreshOperation()
        refreshOperation.refreshLoad = .medium
        
        let taskName = "HomePullDownToRefresh"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(HomeViewController.refreshBackgroundTaskIdentifier)
            HomeViewController.refreshBackgroundTaskIdentifier = .invalid
        }
        HomeViewController.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = { [weak self] in
            Log.optional(refreshOperation.error)
            CrashReporting.shared.reportIfNeeded(error: refreshOperation.error)
            
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                HomeViewController.refreshBackgroundTaskIdentifier = .invalid
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.load(animated: animated)
            }
        }
        AppController.shared.operationQueue.addOperation(refreshOperation)
    }
    
    func showLogoutNoticeIfNeeded() {
        guard AppConfiguration.needsToBeLoggedOut else {
            return
        }
        let controller = UIAlertController(title: "Planetary is ready to move from testing to working with the larger scuttlebutt network",
                                           message: "You can stay in our testing environment or you can completely reset your account and switch to the main scuttlebutt network by selecting Logout and Onboard in the Debug menu",
                                           preferredStyle: .alert)
        var action = UIAlertAction(title: "Cancel", style: .cancel) {
            action in
            controller.dismiss(animated: true, completion: nil)
        }
        controller.addAction(action)

        action = UIAlertAction(title: "Open Debug menu", style: .default) {
            [weak self] action in
            self?.presentDebugMenu()
        }
        controller.addAction(action)
        self.present(controller, animated: true, completion: nil)
    }

    private func update(with proxy: PaginatedKeyValueDataProxy, animated: Bool) {
        if proxy.count == 0 {
            self.tableView.backgroundView = self.emptyView
            self.registerDidRefresh()
        } else {
            self.deeregisterDidRefresh()
            self.emptyView.removeFromSuperview()
            self.tableView.backgroundView = nil
        }
        self.dataSource.update(source: proxy)
        if animated {
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        } else {
            self.tableView.forceReload()
        }
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.refreshAndLoad()
    }
    
    @objc func floatingRefreshButtonDidTouchUpInside(button: UIButton) {
        self.refreshControl.beginRefreshing()
        self.refreshControl.sendActions(for: .valueChanged)
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl.frame.height),
                                        animated: true)
        UIView.animate(withDuration: 1.0,
                       delay: 0,
                       usingSpringWithDamping: CGFloat(0.20),
                       initialSpringVelocity: CGFloat(6.0),
                       options: UIView.AnimationOptions.allowUserInteraction,
                       animations: { self.floatingRefreshButton.transform = CGAffineTransform(scaleX: 0, y: 0) },
                       completion: { _ in self.floatingRefreshButton.isHidden = true })
    }

    @objc func newPostButtonTouchUpInside() {
        Analytics.trackDidTapButton(buttonName: "compose")
        let controller = NewPostViewController()
        controller.didPublish = {
            [weak self] post in
            self?.load()
        }
        controller.addDismissBarButtonItem()
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }
    
    @objc func directoryButtonTouchUpInside() {
        guard let homeViewController = self.parent?.parent as? MainViewController else {
            return
        }
        homeViewController.selectDirectoryTab()
    }

    // MARK: Notifications

    override func didBlockUser(notification: NSNotification) {
        guard let identity = notification.object as? Identity else { return }
        self.tableView.deleteKeyValues(by: identity)
    }
    
    override func didRefresh(notification: NSNotification) {
        DispatchQueue.main.async {
            if self.tableView.backgroundView == self.emptyView {
                self.load(animated: true)
            }
        }
//        self.floatingRefreshButton.transform = CGAffineTransform(scaleX: 0, y: 0)
//        self.floatingRefreshButton.isHidden = false
//        UIView.animate(withDuration: 1.0,
//                       delay: 0,
//                       usingSpringWithDamping: CGFloat(0.20),
//                       initialSpringVelocity: CGFloat(6.0),
//                       options: UIView.AnimationOptions.allowUserInteraction,
//                       animations: { self.floatingRefreshButton.transform = .identity },
//                       completion: { _ in })
    }
}

extension HomeViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

extension HomeViewController: PostReplyPaginatedDataSourceDelegate {
    
    func postReplyView(view: PostReplyView, didLoad keyValue: KeyValue) {
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: keyValue)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue, startReplying: true)
        }
    }
    
    private func pushThreadViewController(with keyValue: KeyValue, startReplying: Bool = false) {
        let controller = ThreadViewController(with: keyValue, startReplying: startReplying)
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
}
