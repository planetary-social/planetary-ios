//
//  ContactCellView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/5/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import ImageSlideshow
import UIKit
import SkeletonView

class ContactCellView: KeyValueView {

    let verticalSpace: CGFloat = 5

    var displayHeader = true {
        didSet {
            self.headerView.isHidden = !self.displayHeader
            self.textViewTopConstraint.constant = self.textViewTopInset
        }
    }

    var keyValue: KeyValue?
    private lazy var headerView = ContactHeaderView()

    private lazy var aboutCellView = AboutCellView()

    var textViewTopConstraint = NSLayoutConstraint()

    var textViewTopInset: CGFloat {
        if self.displayHeader {
            return Layout.contactThumbSize + Layout.verticalSpacing + self.verticalSpace
        } else {
            return self.verticalSpace
        }
    }

    // MARK: Lifecycle

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        self.backgroundColor = .cardBackground

        Layout.fillTop(of: self, with: self.headerView, insets: .topLeftRight)

        let (top, _, _) = Layout.fillTop(of: self,
                                         with: self.aboutCellView,
                                         insets: UIEdgeInsets(top: self.textViewTopInset, left: Layout.postSideMargins, bottom: 0, right: -Layout.postSideMargins),
                                         respectSafeArea: false)
        self.textViewTopConstraint = top
        // self.aboutCellView.constrainHeight(to: MiniAboutCellView.height)

        self.aboutCellView.pinBottomToSuperviewBottom()

        self.isSkeletonable = false
    }

    convenience init(keyValue: KeyValue) {
        assert(keyValue.value.content.isPost)
        self.init()
        self.update(with: keyValue)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: KeyValueUpdateable

    override func update(with keyValue: KeyValue) {
        self.keyValue = keyValue
        self.headerView.update(with: keyValue)

        if let contact = keyValue.value.content.contact {
            let expression: String
            if contact.isFollowing {
                expression = "\(keyValue.value.author) started following \(contact.contact)"
            } else {
                expression = "\(keyValue.value.author) stopped following \(contact.contact)"
            }

            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 16),
                                                             .foregroundColor: UIColor.secondaryText]
            let attributedString = NSAttributedString(string: expression,
                                                      attributes: attributes)
            Bots.current.about(identity: contact.identity) { [weak aboutCellView] about, error in
                aboutCellView?.update(with: contact.identity, about: about)
            }
            Bots.current.follows(identity: contact.identity) { follows, error in
                // TODO: Fill UI
            }
            Bots.current.followedBy(identity: contact.identity) { followedBy, error in
                // TODO: Fill UI
            }

        } else {
            return
        }

        // always do this in case of constraint changes
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
