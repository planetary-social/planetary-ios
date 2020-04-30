//
//  EveryoneViewController.swift
//  Planetary
//
//  Created by Rabble on 4/25/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

import UIKit

class EveryoneViewController: ContentViewController {
    
    private static var refreshBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(newPostButtonTouchUpInside))
        return item
    }()


     lazy var refreshControl: UIRefreshControl = {
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
         titleLabel.text = "Explore Planetary"
         titleLabel.textColor = UIColor.text.default
         titleLabel.textAlignment = .center
         Layout.centerHorizontally(titleLabel, in: view)
         NSLayoutConstraint.activate([
             titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
         ])
         
         let detailLabel = UILabel.forAutoLayout()
         detailLabel.numberOfLines = 0
         detailLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
         detailLabel.text = "The expore tab lets you see more people on Planetary. Specifically it's everything the people you follow are following. "
         detailLabel.textColor = UIColor.text.default
         detailLabel.textAlignment = .center
         view.addSubview(detailLabel)
         NSLayoutConstraint.activate([
             detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
             detailLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 60),
             detailLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -60)
         ])
        /*
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
         */
         
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

    
    init() {
        super.init(scrollable: false, title: .explore)
        /*
        let imageView = UIImageView(image: UIImage(named: "title"))
        imageView.contentMode = .scaleAspectFit
        let view = UIView.forAutoLayout()
        Layout.fill(view: view, with: imageView, respectSafeArea: false)
        self.navigationItem.titleView = view
     */
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
    }

    
    func load(animated: Bool = false) {
        Bots.current.everyone() { [weak self] roots, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.refreshControl.endRefreshing()
            self?.removeLoadingAnimation()
            AppController.shared.hideProgress()
         
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: roots, animated: animated)
            }
        }
    }
    
    func refreshAndLoad(animated: Bool = false) {
        if EveryoneViewController.refreshBackgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(EveryoneViewController.refreshBackgroundTaskIdentifier)
        }
        
        Log.info("Pull down to refresh triggering a medium refresh")
        let refreshOperation = RefreshOperation()
        refreshOperation.refreshLoad = .medium
        
        let taskName = "EveryonePullDownToRefresh"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(EveryoneViewController.refreshBackgroundTaskIdentifier)
            EveryoneViewController.refreshBackgroundTaskIdentifier = .invalid
        }
        EveryoneViewController.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = { [weak self] in
            Log.optional(refreshOperation.error)
            CrashReporting.shared.reportIfNeeded(error: refreshOperation.error)
            
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                EveryoneViewController.refreshBackgroundTaskIdentifier = .invalid
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.load(animated: animated)
            }
        }
        AppController.shared.operationQueue.addOperation(refreshOperation)
    }
    
    
    func update(with roots: KeyValues, animated: Bool) {
        if roots.isEmpty {
            self.tableView.backgroundView = self.emptyView
            self.reloadTimer.start(fireImmediately: false)
        } else {
            self.emptyView.removeFromSuperview()
            self.tableView.backgroundView = nil
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
         self.refreshAndLoad()
     }

     @objc func newPostButtonTouchUpInside() {
         let controller = NewPostViewController()
         controller.didPublish = {
             [weak self] post in
             self?.load()
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

