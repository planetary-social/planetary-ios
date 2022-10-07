//
//  PostReplyView.swift
//  FBTT
//
//  Created by Christoph on 7/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// Composite view of the PostCellView, a ReplyTextView, and a bottom separator.
class PostReplyView: MessageUIView {

    let headerView = ContactHeaderView()

    let postView = PostCellView()

    let repliesView = RepliesView()

    // In this case the view is mostly used a big button to
    // navigate into a thread and start replying.  The tap
    // gesture that comes with the MessageView is applied
    // to the whole view, and the button and text view are
    // disabled.
    let replyTextView: ReplyTextView = {
        let view = ReplyTextView(topSpacing: 0, bottomSpacing: Layout.verticalSpacing)
        view.button.isUserInteractionEnabled = false
        view.isUserInteractionEnabled = false
        view.topSeparator.isHidden = true
        view.addGestureRecognizer(view.tapGesture.recognizer)
        view.backgroundColor = .cardBackground
        return view
    }()
    
    let degrade: UIView = {
        let backgroundView = UIView.forAutoLayout()
        backgroundView.constrainHeight(to: 0)
        let colorView = UIImageView.forAutoLayout()
        colorView.image = UIImage(named: "Thread")
        colorView.contentMode = .scaleToFill
        Layout.fill(view: backgroundView, with: colorView)
        return backgroundView
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView.forAutoLayout()
        stackView.axis = .vertical
        stackView.distribution = .fill
        return stackView
    }()

    init() {
        super.init(frame: .zero)
        self.backgroundColor = .cardBackground
        self.clipsToBounds = true

        let topBorder = Layout.separatorView()
        let bottomBorder = Layout.separatorView()
        
        topBorder.backgroundColor = .cardBorder
        bottomBorder.backgroundColor = .cardBorder
        
        let bottomSeparator = Layout.separatorView(
            height: 10,
            color: .appBackground
        )

        Layout.fill(view: self, with: stackView)
        stackView.addArrangedSubview(topBorder)
        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(postView)
        stackView.addArrangedSubview(repliesView)
        stackView.addArrangedSubview(replyTextView)
        stackView.addArrangedSubview(bottomBorder)
        stackView.addArrangedSubview(degrade)
        stackView.addArrangedSubview(bottomSeparator)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func reset() {
        super.reset()
        replyTextView.isHidden = true
        headerView.isHidden = true
        postView.displayHeader = true
        postView.isHidden = false
        repliesView.isHidden = false
        postView.reset()
    }

    override func update(with message: Message) {
        let isReply = message.content.post?.root != nil
        let isVote = message.content.vote?.root != nil
        if isReply || isVote {
            postView.isHidden = false
            postView.displayHeader = false
            headerView.isHidden = false
            headerView.update(with: message)
            repliesView.isHidden = true
            degrade.heightConstraint?.constant = 0
        } else {
            postView.isHidden = false
            headerView.isHidden = true
            replyTextView.isHidden = message.offChain == true
            repliesView.isHidden = false
            repliesView.update(with: message)
            if !message.metadata.replies.isEmpty {
                degrade.heightConstraint?.constant = 12.33
            } else {
                degrade.heightConstraint?.constant = 0
            }
        }
        postView.update(with: message)
    }
}

extension PostReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.  If the specified
    /// `Message` has images, height for the `GalleryView` is included.  If there are replies
    /// height for the `RepliesView` is added.  This does require some knowledge of the heights
    /// for the various subviews, but this needs to be a very fast call so no complicated calculations
    /// should be done.  Instead, some magic numbers are used based on the various constraints.
    static func estimatedHeight(with message: Message, in superview: UIView) -> CGFloat {
        // starting height based for all non-zero height subviews
        // header + text + reply box
        var height = CGFloat(300)
        guard let post = message.content.post else { return height }

        // add gallery view if necessary
        // note that gallery view is square so likely the same
        // as the width of the superview
        if post.hasBlobs { height += superview.bounds.size.width }

        // add replies view if necessary
        if !message.metadata.replies.isEmpty { height += 35 }

        // done
        return height
    }
}

class RepliesView: MessageUIView {

    private let textFont = UIFont.systemFont(ofSize: 14, weight: .regular)

    let avatarImageView = AvatarStackView()

    var expandedHeight: CGFloat {
        self.avatarImageView.height + Layout.verticalSpacing
    }

    let label = UILabel.forAutoLayout()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addGestureRecognizer(self.tapGesture.recognizer)
        self.label.constrainHeight(to: self.avatarImageView.height)

        Layout.fillTopLeft(of: self, with: self.avatarImageView, insets: .left(Layout.horizontalSpacing))
        Layout.fillTopRight(of: self, with: self.label, insets: .right(-Layout.horizontalSpacing))

        self.label.constrainLeading(toTrailingOf: self.avatarImageView, constant: Layout.horizontalSpacing)

        // creates a height constraint, which we can access as heightConstraint through the UIView extension that add it
        self.constrainHeight(to: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: MessageUpdateable

    override func update(with message: Message) {
        let uniqueAbouts = message.metadata.replies.abouts

        if !uniqueAbouts.isEmpty {
            Bots.current.abouts(identities: uniqueAbouts.map { $0.identity }) { detailedAbouts, _ in
                let allAbouts = Set(detailedAbouts).union(message.metadata.replies.abouts)
                DispatchQueue.main.async {
                    self.avatarImageView.abouts = detailedAbouts
                    self.updateLabel(
                        from: allAbouts,
                        authorsWithDetails: detailedAbouts,
                        totalReplyCount: message.metadata.replies.count
                    )
                }
            }
        }

        self.heightConstraint?.constant = uniqueAbouts.isEmpty ? 0 : self.expandedHeight
    }

    private func updateLabel(from authors: Set<About>, authorsWithDetails: [About], totalReplyCount: Int) {
        let count = authorsWithDetails.count
        if count == 1 {
            let replyFrom = totalReplyCount > 1 ? Text.repliesFrom.text : Text.oneReplyFrom.text
            let text = NSMutableAttributedString(replyFrom, font: self.textFont, color: .secondaryText)
            if let name = authorsWithDetails.first?.name {
                text.append(NSAttributedString(name, font: self.textFont, color: .reactionUser))
            } else {
                text.append(NSAttributedString(Text.oneOther.text, font: self.textFont, color: .reactionUser))
            }
            self.label.attributedText = text
        } else {
            var text: NSMutableAttributedString
            if let name = authorsWithDetails.first?.name {
                text = NSMutableAttributedString(Text.repliesFrom.text, font: self.textFont, color: .secondaryText)
                text.append(NSAttributedString(name, font: self.textFont, color: .reactionUser))
                let others = count > 2 ? Text.andCountOthers : Text.andOneOther
                text.append(
                    NSAttributedString(
                        others.text(["count": String(count - 1)]),
                        font: self.textFont,
                        color: .reactionUser
                    )
                )
            } else {
                // We don't have details from any authors, so just show the number of replies.
                if totalReplyCount == 1 {
                    text = NSMutableAttributedString(
                        Text.oneReply.text,
                        font: self.textFont,
                        color: .secondaryText
                    )
                } else {
                    text = NSMutableAttributedString(
                        Text.replyCount.text(["count": String(totalReplyCount)]),
                        font: self.textFont,
                        color: .secondaryText
                    )
                }
            }
            self.label.attributedText = text
        }
    }
}
