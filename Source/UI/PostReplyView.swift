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
class PostReplyView: KeyValueView {

    let headerView = ContactHeaderView()

    let postView = PostCellView()

    let repliesView = RepliesView()

    let replyView = PostCellView()

    // In this case the view is mostly used a big button to
    // navigate into a thread and start replying.  The tap
    // gesture that comes with the KeyValueView is applied
    // to the whole view, and the button and text view are
    // disabled.
    let replyTextView: ReplyTextView = {
        let view = ReplyTextView(topSpacing: 0, bottomSpacing: Layout.verticalSpacing)
        view.button.isUserInteractionEnabled = false
        view.isUserInteractionEnabled = false
        view.topSeparator.isHidden = true
        view.addGestureRecognizer(view.tapGesture.recognizer)
        view.isSkeletonable = true
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
        let stackView = UIStackView()
        stackView.axis = .vertical
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

        replyView.displayHeader = false

        Layout.fill(view: self, with: stackView)
        stackView.addArrangedSubview(topBorder)
        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(postView)
        stackView.addArrangedSubview(repliesView)
        stackView.addArrangedSubview(replyView)
        stackView.addArrangedSubview(replyTextView)
        stackView.addArrangedSubview(bottomBorder)
        stackView.addArrangedSubview(degrade)
        stackView.addArrangedSubview(bottomSeparator)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func update(with keyValue: KeyValue) {
        let updatePostView = { [weak self] (keyValue: KeyValue) in
            self?.postView.update(with: keyValue)
            self?.repliesView.update(with: keyValue)
            if !keyValue.metadata.replies.isEmpty {
                self?.degrade.heightConstraint?.constant = 12.33
            } else {
                self?.degrade.heightConstraint?.constant = 0
            }
        }
        if let rootIdentifier = keyValue.value.content.post?.root {
            headerView.isHidden = false
            headerView.update(with: keyValue)
            replyView.isHidden = false
            replyView.update(with: keyValue)
            Task {
                do {
                    let rootKeyValue = try Bots.current.post(from: rootIdentifier)
                    updatePostView(rootKeyValue)
                } catch {

                }
            }
        } else if let linkIdentifier = keyValue.value.content.vote?.root {
            headerView.isHidden = false
            headerView.update(with: keyValue)
            replyView.isHidden = true
            Task {
                do {
                    let linkKeyValue = try Bots.current.post(from: linkIdentifier)
                    updatePostView(linkKeyValue)
                } catch {

                }
            }
        } else {
            headerView.isHidden = true
            replyView.isHidden = true
            updatePostView(keyValue)
        }
        replyTextView.isHidden = keyValue.offChain == true
    }
}

extension PostReplyView {

    /// Returns a CGFloat suitable to be used as a `UITableView.estimatedRowHeight` or
    /// `UITableViewDelegate.estimatedRowHeightAtIndexPath()`.  If the specified
    /// `KeyValue` has images, height for the `GalleryView` is included.  If there are replies
    /// height for the `RepliesView` is added.  This does require some knowledge of the heights
    /// for the various subviews, but this needs to be a very fast call so no complicated calculations
    /// should be done.  Instead, some magic numbers are used based on the various constraints.
    static func estimatedHeight(with keyValue: KeyValue, in superview: UIView) -> CGFloat {
        // starting height based for all non-zero height subviews
        // header + text + reply box
        var height = CGFloat(300)
        guard let post = keyValue.value.content.post else { return height }

        // add gallery view if necessary
        // note that gallery view is square so likely the same
        // as the width of the superview
        if post.hasBlobs { height += superview.bounds.size.width }

        // add replies view if necessary
        if !keyValue.metadata.replies.isEmpty { height += 35 }

        // done
        return height
    }
}

class RepliesView: KeyValueView {

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
        Layout.fillTopRight(of: self, with: self.label, insets: .right(Layout.horizontalSpacing))

        self.label.constrainLeading(toTrailingOf: self.avatarImageView, constant: Layout.horizontalSpacing)

        // creates a height constraint, which we can access as heightConstraint through the UIView extension that add it
        self.constrainHeight(to: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {
        let uniqueAbouts = Array(Set(keyValue.metadata.replies.abouts))

        if !uniqueAbouts.isEmpty {
            Bots.current.abouts(identities: uniqueAbouts.map { $0.identity }) { abouts, _ in
                DispatchQueue.main.async {
                    self.avatarImageView.abouts = abouts
                    self.updateLabel(from: abouts, total: keyValue.metadata.replies.count)
                }
            }
        }

        self.heightConstraint?.constant = uniqueAbouts.isEmpty ? 0 : self.expandedHeight
    }

    private func updateLabel(from abouts: [About], total: Int) {
        let count = abouts.count
        if count == 1 {
            let replyFrom = total > 1 ? Text.repliesFrom.text : Text.oneReplyFrom.text
            let text = NSMutableAttributedString(replyFrom, font: self.textFont, color: .secondaryText)
            if let name = abouts.first?.name {
                text.append(NSAttributedString(name, font: self.textFont, color: .reactionUser))
            } else {
                text.append(NSAttributedString(Text.oneOther.text, font: self.textFont, color: .reactionUser))
            }
            self.label.attributedText = text
        } else {
            let text = NSMutableAttributedString(Text.repliesFrom.text, font: self.textFont, color: .secondaryText)
            if let name = abouts.first?.name {
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
                text.append(NSAttributedString(Text.countOthers.text, font: self.textFont, color: .reactionUser))
            }
            self.label.attributedText = text
        }
    }
}
