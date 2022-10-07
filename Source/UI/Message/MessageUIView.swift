//
//  MessageUIView.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessageUIView: UIView, MessageUpdateable {

    /// Default tap gesture for any MessageView.  Subclasses
    /// can overload and assign to any UIView child.  A good
    /// example of this is PostCellView and MessageTableViewDelegate.
    /// Also be aware that if this is used as a base class for a composite
    /// view, like AboutPostView, the tap gesture may need to re-assigned
    /// to a child view so that the MessageTableViewDelegate can correctly
    /// assign the tap gesture to whatever view accepts taps.
    var tapGesture = UIViewTapGesture()

    // MARK: MessageUpdateable

    func update(with message: Message) {}

    func reset() {}
}

extension MessageUIView {

    /// Factory method to return a MessageUIView instance
    /// best suited to the specified `ContentType`.
    static func `for`(_ type: ContentType) -> MessageUIView {
        switch type {
        case .about:
            return AboutView()
        case .contact:
            return ContactCellView()
        case .post:
            return PostCellView()
        case .vote:
            return PostCellView()
        default:
            return UnsupportedView()
        }
    }
}
