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

class ContactCellView: MessageView {

    let verticalSpace: CGFloat = Layout.verticalSpacing

    var displayHeader = true {
        didSet {
            self.headerView.isHidden = !self.displayHeader
            self.textViewTopConstraint.constant = self.textViewTopInset
        }
    }

    var currentTask: Task<Void, Error>?

    var message: Message?

    private lazy var headerView = ContactHeaderView()

    private lazy var aboutView = ExtendedAboutView()

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

        Layout.fillTop(of: self, with: self.headerView)

        let (topConstraint, _, _, _) = Layout.fill(
            view: self,
            with: self.aboutView,
            insets: UIEdgeInsets(
                top: self.textViewTopInset,
                left: Layout.postSideMargins,
                bottom: -verticalSpace,
                right: -Layout.postSideMargins
            ),
            respectSafeArea: false
        )
        self.textViewTopConstraint = topConstraint

        isSkeletonable = true
    }

    convenience init(message: Message) {
        self.init()
        self.update(with: message)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: MessageUpdateable

    override func reset() {
        super.reset()
        currentTask?.cancel()
        aboutView.reset()
        headerView.reset()
        hideSkeleton()
    }

    override func update(with message: Message) {
        self.message = message
        if let contact = message.content.contact {
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
                await self?.aboutView.update(with: identity, about: about)
                await self?.headerView.update(with: message)
                
                var stats = SocialStats(numberOfFollowers: 0, numberOfFollows: 0)
                do {
                    stats = try await Bots.current.socialStats(for: identity)
                } catch {
                    Log.optional(error)
                }
                try Task.checkCancellation()
                await self?.aboutView.update(socialStats: stats)
                
                var hashtags: [Hashtag] = []
                do {
                    hashtags = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                } catch {
                    Log.optional(error)
                }
                try Task.checkCancellation()
                await self?.aboutView.update(hashtags: hashtags)
            }
        } else {
            return
        }

        // always do this in case of constraint changes
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
