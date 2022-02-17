//
//  DiscoverViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger

class DiscoverViewController: ContentViewController {
    
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
    
    private lazy var dataSource: KeyValuePaginatedCollectionViewDataSource = {
        let dataSource = KeyValuePaginatedCollectionViewDataSource()
        return dataSource
        
    }()
    
    private lazy var delegate = KeyValuePaginatedCollectionViewDelegate(on: self)
    
    private lazy var floatingRefreshButton: FloatingRefreshButton = {
        let button = FloatingRefreshButton()
        button.addTarget(self,
                         action: #selector(floatingRefreshButtonDidTouchUpInside(button:)),
                         for: .touchUpInside)
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = PinterestCollectionViewLayout()
        layout.numberOfColumns = self.numberOfColumns
        layout.delegate = self
        
        let view = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.register(PostCollectionViewCell.self, forCellWithReuseIdentifier: "Post")
        view.prefetchDataSource = self.dataSource
        view.refreshControl = self.refreshControl
        view.showsVerticalScrollIndicator = false
        view.contentInset = .square(5)
        view.backgroundColor = .appBackground
        
        return view
    }()
    
    private lazy var numberOfColumns: Int = {
        return Int(UIScreen.main.bounds.width) / 180
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
         
         return view
     }()

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .explore)
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
        Layout.fill(view: self.view, with: self.collectionView)
        
        self.floatingRefreshButton.layout(in: self.view, below: self.collectionView)
        
        self.addLoadingAnimation()
        self.load()
        
        self.registerDidRefresh()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Discover")
        Analytics.shared.trackDidShowScreen(screenName: "discover")
    }
    
    // MARK: Load and refresh
    
    func load(animated: Bool = false) {
        Bots.current.everyone() { [weak self] proxy, error in
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
    
    func refreshAndLoad(animated: Bool = false) {
        if DiscoverViewController.refreshBackgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(DiscoverViewController.refreshBackgroundTaskIdentifier)
        }
        
        Log.info("Pull down to refresh triggering a short refresh")
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        
        let taskName = "DiscoverPullDownToRefresh"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(DiscoverViewController.refreshBackgroundTaskIdentifier)
            DiscoverViewController.refreshBackgroundTaskIdentifier = .invalid
        }
        DiscoverViewController.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = { [weak self] in
            Log.optional(refreshOperation.error)
            CrashReporting.shared.reportIfNeeded(error: refreshOperation.error)
            
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                DiscoverViewController.refreshBackgroundTaskIdentifier = .invalid
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.load(animated: animated)
            }
        }
        AppController.shared.operationQueue.addOperation(refreshOperation)
    }
    
    
    func update(with proxy: PaginatedKeyValueDataProxy, animated: Bool) {
        if proxy.count == 0 {
            self.collectionView.backgroundView = self.emptyView
        } else {
            self.emptyView.removeFromSuperview()
            self.collectionView.backgroundView = nil
        }
        self.dataSource.update(source: proxy)
        self.collectionView.reloadData()
    }
    
    // MARK: Actions

     @objc func refreshControlValueChanged(control: UIRefreshControl) {
         control.beginRefreshing()
         self.refreshAndLoad()
     }
    
    @objc func floatingRefreshButtonDidTouchUpInside(button: FloatingRefreshButton) {
        button.hide()
        self.refreshControl.beginRefreshing()
        self.collectionView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl.frame.height), animated: false)
        self.load(animated: true)
    }

     @objc func newPostButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "compose")
         let controller = NewPostViewController()
         controller.didPublish = {
             [weak self] post in
             self?.load()
         }
         let navController = UINavigationController(rootViewController: controller)
         self.present(navController, animated: true, completion: nil)
     }

     // MARK: Notifications

     override func didBlockUser(notification: NSNotification) {
        // TODO: Finish
         // guard let identity = notification.object as? Identity else { return }
         // self.collectionView.deleteKeyValues(by: identity)
     }
    
    override func didRefresh(notification: NSNotification) {
        let currentProxy = self.dataSource.data
        let currentKeyAtTop = currentProxy.keyValueBy(index: 0)?.key
        Bots.current.keyAtEveryoneTop { [weak self] (key) in
            guard let newKeyAtTop = key, currentKeyAtTop != newKeyAtTop else {
                return
            }
            if currentProxy.count == 0 {
                self?.load(animated: true)
            } else {
                let shouldAnimate = self?.navigationController?.topViewController == self
                self?.floatingRefreshButton.show(animated: shouldAnimate)
            }
        }
    }
}

extension DiscoverViewController: TopScrollable {
    func scrollToTop() {
        self.collectionView.scrollToTop()
    }
}

extension DiscoverViewController: PinterestCollectionViewLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, heightForPhotoAtIndexPath indexPath: IndexPath) -> CGFloat {
        let insets = collectionView.contentInset
        let contentWidth = collectionView.bounds.width - (insets.left + insets.right)
        let cellPadding: CGFloat = 5
        let columnWidth = contentWidth / CGFloat(self.numberOfColumns) - cellPadding * 2
        if let keyValue = dataSource.data.keyValueBy(index: indexPath.row) {
            if let post = keyValue.value.content.post, post.hasBlobs {
                if post.text.withoutGallery().withoutSpacesOrNewlines.isEmpty {
                    return columnWidth
                } else {
                    return columnWidth * 1.618
                }
            } else {
                return columnWidth
            }
        } else {
            return columnWidth
        }
    }
    
}
