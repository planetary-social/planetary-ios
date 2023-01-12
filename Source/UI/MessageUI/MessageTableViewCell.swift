//
//  MessageTableViewCell.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessageTableViewCell: UITableViewCell, MessageUpdateable {

    let type: ContentType
    let messageView: MessageUIView

    init(for type: ContentType, with view: MessageUIView? = nil, height: CGFloat? = nil) {
        self.type = type
        self.messageView = view ?? MessageUIView.for(type)
        super.init(style: .default, reuseIdentifier: type.reuseIdentifier)
        self.constrainMessageViewToContentView(height)
        self.selectionStyle = .none
        backgroundColor = .clear
        self.messageView.showAnimatedSkeleton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constrainMessageViewToContentView(_ height: CGFloat? = nil) {
        let (_, _, bottomConstraint, _) = Layout.fill(
            view: self.contentView,
            with: self.messageView,
            respectSafeArea: false
        )
        bottomConstraint.priority = .required
        guard let height = height else { return }
        let constraint = self.messageView.heightAnchor.constraint(lessThanOrEqualToConstant: height)
        constraint.priority = .defaultHigh
        constraint.isActive = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageView.reset()
    }

    // MARK: MessageUpdateable

    func update(with message: Message) {
        self.messageView.update(with: message)
    }
}
