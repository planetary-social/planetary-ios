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

    private lazy var contactView = ContactView()

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
                                         with: self.contactView,
                                         insets: UIEdgeInsets(top: self.textViewTopInset, left: Layout.postSideMargins, bottom: 0, right: -Layout.postSideMargins),
                                         respectSafeArea: false)
        self.textViewTopConstraint = top
        // self.aboutCellView.constrainHeight(to: MiniAboutCellView.height)

        self.contactView.pinBottomToSuperviewBottom()

    }

    convenience init(keyValue: KeyValue) {
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
            contactView.update(with: contact.identity, about: nil)
            Bots.current.about(identity: contact.identity) { [weak contactView] about, error in
                DispatchQueue.main.async {
                    contactView?.update(with: contact.identity, about: about)
                }
            }
            Bots.current.numberOfFollowers(identity: contact.identity) { [weak contactView] stats, _ in
                DispatchQueue.main.async {
                    contactView?.update(numberOfFollowers: stats.numberOfFollowers, numberOfFollows: stats.numberOfFollows)
                }
            }
            Bots.current.hashtags(identity: contact.identity, limit: 3) { [weak contactView] hashtags, _ in
                DispatchQueue.main.async {
                    contactView?.update(hashtags: hashtags)
                }
            }
        } else {
            return
        }

        // always do this in case of constraint changes
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
