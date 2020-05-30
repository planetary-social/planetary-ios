//
//  ThreadInteractionView.swift
//  FBTT
//
//  Created by Zef Houssney on 9/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class ThreadInteractionView: UIView {

    var replyCount: Int = 0 {
        didSet {
            if self.replyCount == 0 {
                self.replyCountLabel.text = Text.noReplies.text
            } else if self.replyCount == 1 {
                self.replyCountLabel.text = Text.oneReply.text
            } else {
                self.replyCountLabel.text = Text.replyCount.text(["count": "\(self.replyCount)"])
            }
        }
    }
    
    var postIdentifier: Identifier = ""
    //var post: KeyValue = nil
    //var root: KeyValue? = nil

    private lazy var stack: UIStackView = {
        let view = UIStackView.forAutoLayout()
        view.axis = .horizontal
        view.spacing = 19
        return view
    }()

    private let replyCountLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 1
        label.textColor = UIColor.text.detail
        return label
    }()

    private lazy var shareButton: UIButton = {
        let button = UIButton.init(type: .custom)
        button.setImage(UIImage.verse.share, for: .normal)
        button.accessibilityHint = Text.share.text
        button.addTarget(self, action: #selector(didPressShare(sender:)), for: .touchUpInside)
        return button
    }()

    private lazy var bookmarkButton: UIButton = {
        let button = UIButton.init(type: .custom)
        button.setImage(UIImage.verse.bookmark, for: .normal)
        button.accessibilityHint = Text.bookmark.text
        button.addTarget(self, action: #selector(didPressBookmark(sender:)), for: .touchUpInside)
        return button
    }()

    private lazy var likeButton: UIButton = {
        let button = UIButton.init(type: .custom)
        button.setImage(UIImage.verse.like, for: .normal)
        button.accessibilityHint = Text.like.text
        button.addTarget(self, action: #selector(didPressLike(sender:)), for: .touchUpInside)
        return button
    }()

    init() {
        super.init(frame: .zero)
        self.useAutoLayout()
        self.backgroundColor = UIColor.background.default
        
        Layout.addSeparator(toTopOf: self)
        Layout.addSeparator(toBottomOf: self)

        Layout.fill(view: self, with: self.stack, insets: .default)
        self.stack.addArrangedSubview(self.replyCountLabel)

        // spacer separating left/right sides
        self.stack.addArrangedSubview(UIView())
        
        // , self.bookmarkButton,  self.likeButton
        
        for button in [self.shareButton] {
            button.constrainSize(to: 25)
            self.stack.addArrangedSubview(button)

            // TODO: Temporarily hiding buttons, as they don't do anything yet!
            button.isHidden = false
        }

    }
    

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func didPressShare(sender: UIButton) {
        let identity = self.postIdentifier

        Analytics.shared.trackDidTapButton(buttonName: "share")
        
        var actions = [UIAlertAction]()

        let copyMessageIdentifier = UIAlertAction(title: Text.copyMessageIdentifier.text, style: .default) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "copy_profile_identifier")
            UIPasteboard.general.string = identity
            AppController.shared.showToast(Text.identifierCopied.text)
        }
        actions.append(copyMessageIdentifier)
        
        
        //Todo: Clean this up
        // Right now it just lets you copy the message link but ideally it would actually
        // pull up the share sheeet. Which is outlined below but for lack of proper wiring
        // does not work. So we just let you copy identifiers.

        let publicLinkString = identity?.publicLink?.absoluteString
        //if let publicLink = "https://planetary.link/" + identity {
            let copyMesssageLink = UIAlertAction(title: Text.copyMesageLink.text, style: .default) { _ in
                Analytics.shared.trackDidSelectAction(actionName: "copy_profile_identifier")
                UIPasteboard.general.string = publicLinkString
                AppController.shared.showToast(Text.identifierCopied.text)
            }
            actions.append(copyMesssageLink)
        //}
        
        /*
        // TODO: Martin why doesn't this work by bringing up a share sheet
        if let publicLink = identity.publicLink {
            let share = UIAlertAction(title: Text.copyMesageLink.text, style: .default) { [weak self] _ in
                Analytics.shared.trackDidSelectAction(actionName: "share_messsage")
                
                let activityController = UIActivityViewController(activityItems: [publicLink],
                                                                  applicationActivities: nil)
                //self?.present(activityController, animated: true)
                if let popOver = activityController.popoverPresentationController {
                    //popOver.barButtonItem = self?.navigationItem.rightBarButtonItem
                }
            }
            actions.append(share)
        }
        */
        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }
        actions.append(cancel)

        AppController.shared.choose(from: actions)
        

        print(#function)
    }
    @objc func didPressBookmark(sender: UIButton) {
        Analytics.shared.trackDidTapButton(buttonName: "bookmark")

        print(#function)
    }
    @objc func didPressLike(sender: UIButton) {
        Analytics.shared.trackDidTapButton(buttonName: "like")

        print(#function)
    }
}
