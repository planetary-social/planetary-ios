//
//  ExtendedAboutCellView.swift
//  Planetary
//
//  Created by Martin Dutra on 22/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import ImageSlideshow
import UIKit
import SkeletonView
import Logger

class ExtendedAboutCellView: UIView {

    let verticalSpace: CGFloat = Layout.verticalSpacing

    var currentTask: Task<Void, Error>?

    private lazy var aboutView = ExtendedAboutView()

    var textViewTopConstraint = NSLayoutConstraint()

    var textViewTopInset: CGFloat {
        verticalSpace
    }

    // MARK: Lifecycle

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        self.backgroundColor = .cardBackground

        Layout.fill(
            view: self,
            with: aboutView,
            insets: UIEdgeInsets(
                top: Layout.verticalSpacing,
                left: Layout.postSideMargins,
                bottom: -Layout.verticalSpacing,
                right: -Layout.postSideMargins
            ),
            respectSafeArea: false
        )

        isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: MessageUpdateable

    func reset() {
        currentTask?.cancel()
        aboutView.reset()
        hideSkeleton()
    }

    func update(with identity: Identity, about: About?, star: Star? = nil) {
        showAnimatedSkeleton()
        currentTask = Task.detached { [weak self] in
            // The idea here is to execute the three database queries in order so that if the task is cancelled
            // in the middle we can omit at least one of them
            var loadedAbout = about
            if about == nil {
                try Task.checkCancellation()
                do {
                    loadedAbout = try await Bots.current.about(identity: identity)
                } catch {
                    Log.optional(error)
                }
            }
            try Task.checkCancellation()
            await self?.aboutView.update(with: identity, about: loadedAbout, star: star)

            var stats: SocialStats?
            if loadedAbout != nil {
                do {
                    stats = try await Bots.current.socialStats(for: identity)
                } catch {
                    stats = SocialStats(numberOfFollowers: 0, numberOfFollows: 0)
                    Log.optional(error)
                }
            }
            try Task.checkCancellation()
            await self?.aboutView.update(socialStats: stats)

            var hashtags: [Hashtag] = []
            if loadedAbout != nil {
                do {
                    hashtags = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                } catch {
                    Log.optional(error)
                }
            }
            try Task.checkCancellation()
            await self?.aboutView.update(hashtags: hashtags)
        }

        // always do this in case of constraint changes
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}

class ExtendedAboutTableViewCell: UITableViewCell {

    let aboutView = ExtendedAboutCellView()

    convenience init() {
        self.init(style: .default, reuseIdentifier: "ExtendedAboutTableViewCell")
        self.selectionStyle = .none
        Layout.fill(view: self.contentView, with: self.aboutView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.aboutView.reset()
    }
}
