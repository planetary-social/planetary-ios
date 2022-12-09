//
//  DiscoverViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting

class DiscoverViewController: ContentViewController, UISearchResultsUpdating, UISearchBarDelegate,
    UniversalSearchDelegate, HelpDrawerHost {
    
    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage.navIconWrite
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(newPostButtonTouchUpInside)
        )
        return item
    }()
    
    lazy var helpButton: UIBarButtonItem = { HelpDrawerCoordinator.helpBarButton(for: self) }()
    var helpDrawerType: HelpDrawer { .discover }
    
    lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()
    
    private lazy var dataSource: MessagePaginatedCollectionViewDataSource = {
        let dataSource = MessagePaginatedCollectionViewDataSource()
        return dataSource
    }()
    
    private lazy var delegate = MessagePaginatedCollectionViewDelegate(on: self)
    
    private lazy var floatingRefreshButton: FloatingRefreshButton = {
        let button = FloatingRefreshButton()
        button.addTarget(
            self,
            action: #selector(floatingRefreshButtonDidTouchUpInside(button:)),
            for: .touchUpInside
        )
        return button
    }()
    
    private lazy var collectionViewLayout: PinterestCollectionViewLayout = {
        let layout = PinterestCollectionViewLayout()
        layout.delegate = self
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.view.bounds, collectionViewLayout: collectionViewLayout)
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
    
    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.searchBar.isTranslucent = false
        controller.searchBar.placeholder = Localized.search.text
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()
    
    private lazy var numberOfColumns: Int = {
        Int(UIScreen.main.bounds.width) / 180
    }()
     
    private lazy var emptyDiscoverView: UIView = {
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
    
    private lazy var searchResultsView: UniversalSearchResultsView = {
        let view = UniversalSearchResultsView()
        view.delegate = self
        return view
    }()
    
    // for a bug fix — see note in Search extension below
    private var searchEditBeginDate = Date()

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .explore)
        self.navigationItem.rightBarButtonItems = [newPostBarButtonItem, helpButton]
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }
    
    override init(scrollable: Bool = true, title: Localized? = nil, dynamicTitle: String? = nil) {
        super.init(scrollable: scrollable, title: title, dynamicTitle: dynamicTitle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.searchController = self.searchController
        showDiscoverCollectionView()
        // self.floatingRefreshButton.layout(in: self.view, below: self.collectionView)
        
        self.addLoadingAnimation()
        self.load()
        
        self.registerDidRefresh()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeDiscoverFeedAlgorithm(notification:)),
            name: .didChangeDiscoverFeedAlgorithm,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Discover")
        Analytics.shared.trackDidShowScreen(screenName: "discover")
        HelpDrawerCoordinator.showFirstTimeHelp(for: self)
    }
    
    // MARK: Load and refresh
    
    func load(animated: Bool = false) {
        Bots.current.everyone { [weak self] proxy, error in
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
    
    func update(with proxy: PaginatedMessageDataProxy, animated: Bool) {
        if proxy.count == 0 {
            self.collectionView.backgroundView = self.emptyDiscoverView
        } else {
            self.emptyDiscoverView.removeFromSuperview()
            self.collectionView.backgroundView = nil
        }
        self.dataSource.update(source: proxy)
        self.collectionView.reloadData()
    }
    
    @objc
    func didChangeDiscoverFeedAlgorithm(notification: Notification) {
        load(animated: true)
    }
    
    // MARK: Search
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        Analytics.shared.trackDidTapSearchbar(searchBarName: "discover")
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        searchResultsView.searchQuery = searchController.searchBar.text ?? ""
        if searchResultsView.searchQuery.isEmpty {
            showDiscoverCollectionView()
        } else {
            showSearchResults()
        }
    }
    
    // These two functions are implemented to avoid a bug where the initial
    // tap of the search bar begins editing, but first responder is immediately resigned
    // I can't figure out why this is happening, but this is a potential solution to avoid the bug.
    // I set a symbolic breakpoint and can't find why resignFirstResponder is being called there.
    //
    // first, when the edit begins, we store the date in self.searchEditBeginDate
    // then, in searchBarShouldEndEditing, we check whether this date was extremely recent
    // if it was too recent to be performed intentionally, we don't allow the field to end editing.
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.searchEditBeginDate = Date()
        return true
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        let timeSinceStart = Date().timeIntervalSince(self.searchEditBeginDate)
        return timeSinceStart > 0.4
    }
    
    func showDiscoverCollectionView() {
        view.subviews.forEach { $0.removeFromSuperview() }
        Layout.fill(view: self.view, with: self.collectionView)
    }
    
    func showSearchResults() {
        view.subviews.forEach { $0.removeFromSuperview() }
        Layout.fill(view: self.view, with: self.searchResultsView)
    }
    
    func present(_ controller: UIViewController) {
        navigationController?.pushViewController(controller, animated: true)
    }
    
    // MARK: Actions

    @objc
    func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load(animated: true)
    }
    
    @objc
    func floatingRefreshButtonDidTouchUpInside(button: FloatingRefreshButton) {
        button.hide()
        self.refreshControl.beginRefreshing()
        self.collectionView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl.frame.height), animated: false)
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
    
    // MARK: Notifications

    override func didBlockUser(notification: Notification) {
        // guard let identity = notification.object as? Identity else { return }
        // self.collectionView.deleteMessages(by: identity)
    }
    
    override func didRefresh(notification: Notification) {
//        let currentProxy = self.dataSource.data
//        let currentKeyAtTop = currentProxy.messageBy(index: 0)?.key
//        Bots.current.keyAtEveryoneTop { [weak self] (key) in
//            guard let newKeyAtTop = key, currentKeyAtTop != newKeyAtTop else {
//                return
//            }
//            if currentProxy.count == 0 {
//                self?.load(animated: true)
//            } else {
//                let shouldAnimate = self?.navigationController?.topViewController == self
//                self?.floatingRefreshButton.show(animated: shouldAnimate)
//            }
//        }
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
        let columnWidth = contentWidth / CGFloat(collectionViewLayout.numberOfColumns) - cellPadding * 2
        if let message = dataSource.data.messageBy(index: indexPath.row) {
            if let post = message.content.post, post.hasBlobs {
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
