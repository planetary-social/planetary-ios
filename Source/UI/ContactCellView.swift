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
import Logger

class ContactCellView: KeyValueView {

    let verticalSpace: CGFloat = 5

    var displayHeader = true {
        didSet {
            self.headerView.isHidden = !self.displayHeader
            self.textViewTopConstraint.constant = self.textViewTopInset
        }
    }

    var currentTask: Task<Void, Error>?

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

        let (topConstraint, _, _) = Layout.fillTop(
            of: self,
            with: self.contactView,
            insets: UIEdgeInsets(
                top: self.textViewTopInset,
                left: Layout.postSideMargins,
                bottom: 0,
                right: -Layout.postSideMargins
            ),
            respectSafeArea: false
        )
        self.textViewTopConstraint = topConstraint

        self.contactView.pinBottomToSuperviewBottom()

        isSkeletonable = true
    }

    convenience init(keyValue: KeyValue) {
        self.init()
        self.update(with: keyValue)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: KeyValueUpdateable

    override func reset() {
        super.reset()
        currentTask?.cancel()
        contactView.reset()
        headerView.reset()
        hideSkeleton()
    }

    override func update(with keyValue: KeyValue) {
        self.keyValue = keyValue
        if let contact = keyValue.value.content.contact {
            let identity = contact.identity
            showAnimatedSkeleton()
            currentTask = Task.detached { [weak self] in
                // The idea here is to execute the three database queries in order so that if the task is cancelled
                // in the middle we can omit at least one of them
                try Task.checkCancellation()
                var about: About?
                do {
                    about = try await Bots.current.about(identity: identity)
                } catch {
                    Log.optional(error)
                }
                try Task.checkCancellation()
                await self?.contactView.update(with: identity, about: about)
                await self?.headerView.update(with: keyValue)
                await self?.headerView.hideSkeleton()
                
                var stats = SocialStats(numberOfFollowers: 0, numberOfFollows: 0)
                do {
                    stats = try await Bots.current.socialStats(for: identity)
                } catch {
                    Log.optional(error)
                }
                try Task.checkCancellation()
                await self?.contactView.update(socialStats: stats)
                
                var hashtags: [Hashtag] = []
                do {
                    hashtags = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                } catch {
                    Log.optional(error)
                }
                try Task.checkCancellation()
                await self?.contactView.update(hashtags: hashtags)
            }
        } else {
            return
        }

        // always do this in case of constraint changes
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
