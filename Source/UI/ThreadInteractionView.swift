//
//  ThreadInteractionView.swift
//  FBTT
//
//  Created by Zef Houssney on 9/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

protocol ThreadInteractionViewDelegate: class {
    
    func threadInteractionView(_ view: ThreadInteractionView, didLike post: KeyValue)
    
}

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
    
    weak var delegate: ThreadInteractionViewDelegate?
    
    var post: KeyValue? = nil
    var replies: StaticDataProxy?
    var userLikes: Bool = false
    
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
        
        Layout.addSeparator(toTopOf: self)
        Layout.addSeparator(toBottomOf: self)

        Layout.fill(view: self, with: self.stack, insets: .default)
        self.stack.addArrangedSubview(self.replyCountLabel)

        // spacer separating left/right sides
        self.stack.addArrangedSubview(UIView())

        for button in [self.likeButton, self.shareButton] {
            button.constrainSize(to: 25)
            self.stack.addArrangedSubview(button)
        }
        
        // Lets hide the like button and wait until update() finishes to show it
        self.likeButton.isHidden = true
        
        self.shareButton.isHidden = false
    }
    
    func update() {
        //check to see if we're currently linking this post
        let me = Bots.current.identity
        if self.replies!.count-1 >= 0 {
            for index in 0...self.replies!.count-1 {
                if self.replies!.keyValueBy(index: index)?.value.content.type ==  Planetary.ContentType.vote {
                    let likeIdentity = self.replies!.keyValueBy(index: index)?.metadata.author.about?.about
                    if me == likeIdentity {
                        self.userLikes = true
                    }
                }
            }
        }
            
        if self.userLikes {
            self.likeButton.setImage(UIImage.verse.liked, for: .normal)
        } else {
            self.likeButton.setImage(UIImage.verse.like, for: .normal)
        }
        self.likeButton.isHidden = false
    }
    

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func didPressShare(sender: UIButton) {
        guard let post = self.post else {
            return
        }

        Analytics.shared.trackDidTapButton(buttonName: "share")
        
        var actions = [UIAlertAction]()

        let copyMessageIdentifier = UIAlertAction(title: Text.copyMessageIdentifier.text, style: .default) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "copy_message_identifier")
            UIPasteboard.general.string = post.key
            AppController.shared.showToast(Text.identifierCopied.text)
        }
        actions.append(copyMessageIdentifier)
        
        let copyMesssageLink = UIAlertAction(title: Text.shareThisMessage.text, style: .default) { _ in
            guard let publicLink = post.key.publicLink else {
                return
            }
            
            let who = post.metadata.author.about?.nameOrIdentity ?? post.value.author
            let link = publicLink.absoluteString
            let postWithoutGallery = post.value.content.post?.text.withoutGallery() ?? ""
            let what = postWithoutGallery.prefix(280 - who.count - link.count - Text.shareThisMessageText.text.count)
            let text = Text.shareThisMessageText.text(["who": who,
                                                       "what": String(what),
                                                       "link": publicLink.absoluteString])
            Analytics.shared.trackDidSelectAction(actionName: "share_message")
            let activityController = UIActivityViewController(activityItems: [text],
                                                              applicationActivities: nil)
            AppController.shared.present(activityController, animated: true)
            if let popOver = activityController.popoverPresentationController {
                popOver.sourceView = self
            }
        }
        actions.append(copyMesssageLink)

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }
        actions.append(cancel)

        AppController.shared.choose(from: actions, sourceView: sender)
        

        print(#function)
    }
    @objc func didPressBookmark(sender: UIButton) {
        Analytics.shared.trackDidTapButton(buttonName: "bookmark")

        print(#function)
    }
    
    @objc func didPressLike(sender: UIButton) {
        guard let post = self.post, !self.userLikes else {
            return
        }
        
        Analytics.shared.trackDidTapButton(buttonName: "like")
        sender.setImage(UIImage.verse.liked, for: .normal)
        
        sender.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 2.0,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 6.0,
                       options: .allowUserInteraction,
                       animations: { sender.transform = .identity },
                       completion: nil)
        
        self.delegate?.threadInteractionView(self, didLike: post)
    }
}
