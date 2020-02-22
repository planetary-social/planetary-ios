//
//  HomeViewController.swift
//  FBTT
//
//  Created by Christoph on 2/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftyMarkdown
import UIKit

class HomeViewController: ContentViewController {

    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(newPostButtonTouchUpInside))
        return item
    }()

    private lazy var selectPhotoBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-camera")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(selectPhotoButtonTouchUpInside))
        return item
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    private let dataSource = PostReplyDataSource()
    private lazy var delegate = PostReplyDelegate(on: self)
    private let prefetchDataSource = PostReplyDataSourcePrefetching()

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.prefetchDataSource = self.prefetchDataSource
        view.refreshControl = self.refreshControl
        view.sectionHeaderHeight = 0
        view.separatorStyle = .none
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
    
    private lazy var reloadTimer: RepeatingTimer = {
        // Set timer to 3 minutes
        let timer = RepeatingTimer(interval: 60 * 3) { [weak self] in
            self?.emptyView.removeFromSuperview()
            self?.addLoadingAnimation()
            self?.load(animated: true)
        }
        return timer
    }()
    
    private lazy var loadingAnimation: PeerConnectionAnimation = {
        let view = PeerConnectionAnimation.forAutoLayout()
        view.setDotCount(inside: false, count: 1, animated: false)
        view.setDotCount(inside: true, count: 2, animated: false)
        return view
    }()
    
    private lazy var loadingLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.textAlignment = .center
        view.numberOfLines = 2
        view.text = Text.loadingUpdates.text
        view.textColor = UIColor.tint.default
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

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.addLoadingAnimation()
        self.load()
        self.showLogoutNoticeIfNeeded()
    }

    // MARK: Load and refresh
    
    private func addLoadingAnimation() {
        Layout.center(self.loadingLabel, in: self.view)
        Layout.centerHorizontally(self.loadingAnimation, in: self.view)
        self.loadingAnimation.constrainSize(to: self.loadingAnimation.totalDiameter)
        self.loadingAnimation.pinBottom(toTopOf: self.loadingLabel, constant: -20, activate: true)
    }
    
    private func removeLoadingAnimation() {
        self.loadingLabel.removeFromSuperview()
        self.loadingAnimation.removeFromSuperview()
    }

    private func load(animated: Bool = false) {
        Bots.current.refresh() {
            _, _ in
            Bots.current.recent() {
                [weak self] roots, error in
                self?.update(with: roots, animated: animated)
                self?.refreshControl.endRefreshing()
                self?.removeLoadingAnimation()
                AppController.shared.hideProgress()
            }
        }
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

    func refresh() {
        self.load()
    }

    private func update(with roots: KeyValues, animated: Bool) {
        if roots.isEmpty {
            self.tableView.backgroundView = self.emptyView
            self.reloadTimer.start(fireImmediately: false)
        } else {
            self.emptyView.removeFromSuperview()
            self.reloadTimer.stop()
        }
        self.dataSource.keyValues = roots
        if animated {
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        } else {
            self.tableView.forceReload()
        }
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.refresh()
    }

    @objc func newPostButtonTouchUpInside() {
        let controller = NewPostViewController()
        controller.didPublish = {
            [weak self] post in
            self?.refresh()
        }
        controller.addDismissBarButtonItem()
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func selectPhotoButtonTouchUpInside() {
        let controller = ContentViewController(scrollable: false, title: .select)
        controller.addDismissBarButtonItem()
        let navController = UINavigationController(rootViewController: controller)
        AppController.shared.present(navController, animated: true, completion: nil)
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
}

extension HomeViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}
