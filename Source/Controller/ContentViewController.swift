//
//  ContentViewController.swift
//  FBTT
//
//  Created by Christoph on 2/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// This view controller is suitable to be used for all app feature
/// controllers.  It provides some features useful for varying screen
/// heights and scrolling content.
///
/// First, a `contentView` is provided as the preferred root view to
/// build your UI.
///
/// Second, the `scrollable` flag determines how the `contentView` will
/// grow depending on it's intrinsic height, and what happens when the
/// keyboard appears.
///
/// If `scrollable = true`, the `contentView` will continue to grow
/// for all the subviews, and the internal `scrollView` will compensate.
/// This is ideal for heterogenous content that does not contain
/// scrolling views.  This is also the default value.
///
/// If `scrollable = false`, the `contentView` will be fit within the
/// `scrollView` safe area.  On iPhone X-style devices, this means the
/// bottom constraint will be north of the "swipe up" control.
///
/// Additionally, the controller can be keyboard aware by setting
/// `isKeyboardHandlingEnabled = true`.  When the keyboard appears,
/// the `contentView` bottom constraint moves up, and the `scrollView`
/// will become active if the `contentView` is partially obscured.
/// Reacting to the keyboard is disabled during `viewWillDisappear`
/// and enabled (if set) during `viewWillAppear`. Check out the
/// `KeyboardHandling` protocol for more details.
class ContentViewController: UIViewController, KeyboardHandling {

    let scrollable: Bool
    let scrollView = UIScrollView.default()
    var contentView = UIView.forAutoLayout()
    private var contentViewBottomConstraint: NSLayoutConstraint!

    var showsTabBarBorder = true

    // MARK: Lifecycle

    // `dynamicTitle` is used to provide a string at runtime instead of the strongly-typed `title` Text object.
    // it will not be used if `title` is also provided
    init(scrollable: Bool = true, title: Localized? = nil, dynamicTitle: String? = nil) {
        self.scrollable = scrollable
        super.init(nibName: nil, bundle: nil)
        self.title = title?.text ?? dynamicTitle
        self.debugLabel.text = "\(self.title ?? "Some") content\ngoes here"
        self.removeBackItemText()
        self.registerNotifications()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.deregisterNotifications()
    }

    // MARK: Layout

    override func loadView() {
        self.view = UIView(frame: CGRect.zero)
        self.view.backgroundColor = .appBackground
        Layout.center(self.debugLabel, in: self.view)
        self.loadViewWithScrollView()
    }

    /// Creates a vertical scroll view with a vertical content view
    /// that is suitable for fullscreen view controllers.  This will
    /// allow the content view to grow be scrollable only when larger
    /// than the screen, with consideration for keyboard visibility.
    private func loadViewWithScrollView() {
        Layout.fill(scrollView: self.scrollView, with: self.contentView, scrollable: self.scrollable)
        let (_, _, bottom, _) = Layout.fill(view: self.view, with: scrollView, respectSafeArea: true)
        bottom.priority = .required
        self.contentViewBottomConstraint = bottom
    }

    /// Creates a vertical content view directly in the controller's view.
    /// The content view will resize depending on keyboard visibility.
    /// This is currently not used, but left in while loadViewWithScrollView()
    /// is perfected.
    private func loadViewWithContentView() {
        let (_, _, bottom, _) = Layout.fill(view: self.view,with: self.contentView, respectSafeArea: false)
        self.contentViewBottomConstraint = bottom
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addSubviews()
        self.constrainSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.showDebugLabelIfNecessary()
        if self.isKeyboardHandlingEnabled {
            self.registerForKeyboardNotifications()
        }

        if !self.showsTabBarBorder {
            AppController.shared.mainViewController?.setTopBorder(hidden: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.deregisterForKeyboardNotifications()

        if !self.showsTabBarBorder {
            AppController.shared.mainViewController?.setTopBorder(hidden: false)
        }
    }
    
    func addSubviews() {
        // clients are encouraged to override but must call super
    }

    func constrainSubviews() {
        // clients are encouraged to override but must call super
    }

    // MARK: Keyboard handling

    var isKeyboardHandlingEnabled = false {
        didSet {
            isKeyboardHandlingEnabled ?
                self.registerForKeyboardNotifications() :
                self.deregisterForKeyboardNotifications()
        }
    }

    func setKeyboardTopConstraint(
        constant: CGFloat,
        duration: TimeInterval,
        curve: UIView.AnimationCurve
    ) {
        let animator = UIViewPropertyAnimator(duration: duration, curve: curve) { [weak self] in
            self?.contentViewBottomConstraint.constant = constant
        }
        animator.startAnimation()
    }

    // MARK: Debug

    internal let debugLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.alpha = 0
        label.font = .boldSystemFont(ofSize: 24)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .lightGray
        return label
    }()

    func setDebugLabel(text: String) {
        self.debugLabel.alpha = 1
        self.debugLabel.text = text
    }

    func setDebugLabel(error: Error) {
        let error = (error as? GoBotError) ?? (error as? FakeBotError) ?? error
        self.setDebugLabel(text: "\(error)")
    }

    private func showDebugLabelIfNecessary() {
        self.debugLabel.alpha = self.contentView.subviews.isEmpty ? 1 : 0
    }

    // MARK: Notifications

    func registerNotifications() {
        self.registerDidBlockUser()
    }

    func deregisterNotifications() {
        self.deregisterDidBlockUser()
    }
    
    // MARK: Loading animation
    
    private lazy var loadingAnimation: PeerConnectionAnimation = {
        let view = PeerConnectionAnimation(color: .networkAnimation)
        view.setDotCount(inside: false, count: 1, animated: false)
        view.setDotCount(inside: true, count: 2, animated: false)
        return view
    }()
    
    private lazy var loadingLabel: UILabel = {
        let view = UILabel.forAutoLayout()
        view.textAlignment = .center
        view.numberOfLines = 2
        view.text = Localized.loadingUpdates.text
        view.textColor = UIColor.tint.default
        return view
    }()
    
    func addLoadingAnimation() {
        Layout.center(self.loadingLabel, in: self.view)
        Layout.centerHorizontally(self.loadingAnimation, in: self.view)
        self.loadingAnimation.constrainSize(to: self.loadingAnimation.totalDiameter)
        self.loadingAnimation.pinBottom(toTopOf: self.loadingLabel, constant: -20, activate: true)
    }
    
    func removeLoadingAnimation() {
        self.loadingLabel.removeFromSuperview()
        self.loadingAnimation.removeFromSuperview()
    }
}
