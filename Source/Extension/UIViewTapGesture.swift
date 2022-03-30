//
//  UITextViewTapGesture.swift
//  FBTT
//
//  Created by Christoph on 4/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class UIViewTapGesture: Tappable {

    /// Default closure to open the tapped URL with the AppController.
    /// Be aware of retain cycles if using `self` in the closure.
    var tapOnURL: ((URL) -> Void)? = {
        url in
        AppController.shared.open(url: url)
    }

    /// Closure to handle a tap in the view that is NOT on a URL.
    /// Be aware of retain cycles if using `self` in the closure.
    var tap: (() -> Void)?

    /// Default single tap gesture recognizer.  This can be changed before
    /// being assigned to a view.
    lazy var recognizer = UITapGestureRecognizer(target: self, action: #selector(tap(gesture:)))

    /// Basic marshaller of the tap gesture into a location, then to be handled
    /// based on the view type.
    @objc func tap(gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: view)
        if let textView = view as? UITextView { self.tapped(textView, at: location) } else { self.tapped(view, at: location) }
    }

    // MARK: Base class UIView support

    private func tapped(_ view: UIView, at location: CGPoint) {
        self.tap?()
    }

    // MARK: UITextView support

    /// On tap, searches the attributed sections of the string.  If the tap location
    /// lands on the URL, the `tapOnURL` closure is called with the URL.  If tapped
    /// elsewhere, the `tap` closure is called.
    private func tapped(_ textView: UITextView, at location: CGPoint) {
        let characterIndex = textView.layoutManager.characterIndex(for: location,
                                                                   in: textView.textContainer,
                                                                   fractionOfDistanceBetweenInsertionPoints: nil)
        guard characterIndex < textView.textStorage.length else { return }
        let attributes = textView.textStorage.attributes(at: characterIndex,
                                                         effectiveRange: nil)
        let link = attributes[NSAttributedString.Key.link]
        if let url = self.linkToURL(link) {
            AppController.shared.open(url: url)
        } else if let string = link as? String {
            AppController.shared.open(string: string)
        } else {
            self.tap?()
        }
    }

    private func linkToURL(_ link: Any?) -> URL? {
        if let link = link as? String { return URL(string: link) } else if let link = link as? URL { return link } else { return nil }
    }
}
