//
//  PostViewController.swift
//  FBTT
//
//  Created by Christoph on 4/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class PostViewController: ContentViewController {

    private let keyValue: KeyValue

    private let scrollView = UIScrollView.default()

    private let postView = PostCellView()

    private let replyTextView = ReplyTextView()

    private let buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        view.postButton.action = didPressPostButton
        view.topSeparator.isHidden = true
        return view
    }()

    init(with keyValue: KeyValue) {
        self.keyValue = keyValue
        super.init(scrollable: false, title: "Reply to")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Layout.fill(scrollView: self.scrollView, with: self.postView)
        Layout.fillTop(of: self.contentView, with: self.scrollView, insets: nil, respectSafeArea: false)
        Layout.add(subview: self.replyTextView, toBottomOf: self.scrollView, insets: nil)
        Layout.fillBottom(of: self.contentView, with: self.buttonsView, insets: nil, respectSafeArea: false)
        self.replyTextView.pinBottom(toTopOf: self.buttonsView)

        // the bottom of the scroll view touches the top of the reply view
        // but the reply view can only grow to a certain height
        self.replyTextView.heightAnchor.constraint(lessThanOrEqualToConstant: ReplyTextView.maxHeight).isActive = true
        self.buttonsView.constrainHeight(to: PostButtonsView.viewHeight)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.registerForKeyboardNotifications()
        self.load()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.deregisterForKeyboardNotifications()
    }

    private func load() {
        self.postView.update(with: self.keyValue)
    }

    // MARK: Actions

    func didPressPostButton() {
        guard let text = self.replyTextView.textView.attributedText, text.length > 0 else { return }
        let branches = [self.keyValue.key]
        let root = self.keyValue.value.content.post?.root ?? self.keyValue.key
        let post = Post(attributedText: text, branches: branches, root: root)
        // AppController.shared.showProgress()
        Bots.current.publish(post) {
            [unowned self] _, error in
            Log.optional(error)
            AppController.shared.hideProgress()
            self.navigationController?.popViewController(animated: true)
        }
    }
}
