//
//  MentionTextViewDelegate.swift
//  FBTT
//
//  Created by Christoph on 7/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MentionTextViewDelegate: NSObject, UITextViewDelegate {

    /// This seems to be the best way to do this for now.
    /// This requires that if the related text view changes
    /// font then this delegate needs to be updated too.
    var font: UIFont
    var color: UIColor
    var placeholderColor: UIColor

    var placeholder: String?

    var fontAttributes: [NSAttributedString.Key: Any] {
        [
            NSAttributedString.Key.font: self.font,
            NSAttributedString.Key.foregroundColor: self.color
        ]
    }

    internal var mentionRange: NSRange?

    // This is necessary to prevent the UITextView delegate from
    // handling pasted text or keyboard suggestions twice.
    internal var ignoreTextViewDelegateWhileReplacingText = false

    init(font: UIFont, color: UIColor, placeholderText: Localized? = nil, placeholderColor: UIColor? = nil) {
        self.font = font
        self.color = color
        self.placeholder = placeholderText?.text
        self.placeholderColor = placeholderColor ?? color
    }

    /// This is called whenever text is inserted into the UITextView.
    /// If the selectedRange is outside of the potential mention range
    /// then mention is cancelled and the menu should be closed.
    func textViewDidChangeSelection(_ textView: UITextView) {
        if self.ignoreTextViewDelegateWhileReplacingText { return }
        guard let mentionRange = self.mentionRange else { return }
        let location = textView.selectedRange.location
        if location < mentionRange.lowerBound || location > mentionRange.upperBound {
            self.clear()
        }
    }

    /// Convenience function to apply the known attributes to the specified
    /// text and replace as an attributed string.  If using this function in
    /// UITextViewDelegate.textView(shouldChangeTextIn) then that function
    /// should always return false, otherwise the text will be inserted with
    /// whatever attributes are adjacent to the specified NSRange.
    private func textView(_ textView: UITextView,
                          replaceTextIn range: NSRange,
                          with text: String) {
        self.ignoreTextViewDelegateWhileReplacingText = true
        let text = NSMutableAttributedString(string: text, attributes: self.fontAttributes)
        textView.replaceText(in: range, with: text)
        self.ignoreTextViewDelegateWhileReplacingText = false
        self.textViewDidChange(textView)
    }

    /// This is the really critical part of mention processing as it
    /// analyzes the replacement text to determine if a mention is
    /// being started, completed, cancelled or deleted.
    /// BE VERY CAREFUL WHEN CHANGING THIS CODE.
    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        // textView(replaceTextIn: range) sets this flag to prevent
        // the eventual UITextView.attributedText = mutableText from
        // causing the delegate to insert the same text twice.  It is
        // CRITICAL that this func ONLY calls textView(replaceTextIn: range)
        // and returns false, otherwise pasted text or keyboard suggestions
        // will not be inserted correctly.
        if self.ignoreTextViewDelegateWhileReplacingText { return false }

        // delete entire text and attributes
        if text.isEmpty && textView.attributedText.range == range {
            self.mentionRange = nil
            textView.typingAttributes = self.fontAttributes
            return true
        }

        // delete embedded mention
        else if text.isEmpty {
            let mentionsWithRanges = textView.attributedText.mentionsWithRanges()
            let ranges = mentionsWithRanges.filter { $0.1.contains(range.location) }.map { $0.1 }
            if let range = ranges.first {
                self.textView(textView, replaceTextIn: range, with: "")
                return false
            }
        }

        // stop tracking potential mention
        // or reset attributes for new text
        else if text.hasPrefix(" ") || text.hasPrefix("\n") {
            self.mentionRange = nil
            textView.typingAttributes = self.fontAttributes
            return true
        }

        // start mention
        else if text.starts(with: "@") {
            self.mentionRange = NSRange(location: range.location, length: text.count)
        }

        // if no potential mention then reset the typing
        // attributes and allow the text view to insert text
        guard let mentionRange = self.mentionRange else {
            textView.typingAttributes = self.fontAttributes
            return true
        }

        // add to end of mention
        if range.lowerBound == mentionRange.upperBound && text.count > 0 {
            let textRange = NSRange(location: range.location, length: text.count)
            self.mentionRange = mentionRange.union(textRange)
        }

        // delete mention
        else if range.location == mentionRange.location && text.isEmpty {
            self.mentionRange = nil
        }

        // insert, replace or delete characters
        else if let _ = mentionRange.intersection(range) {

            // delete
            if text.isEmpty {
                let location = mentionRange.location
                let length = mentionRange.length - range.length
                self.mentionRange = NSRange(location: location, length: length)
            }

            // insert or replace
            else {
                let textRange = NSRange(location: range.location, length: text.count)
                self.mentionRange = mentionRange.union(textRange)
            }
        }

        // always reset the typing attributes to ensure
        // that the text view does not use adjacent attributes
        textView.typingAttributes = self.fontAttributes
        return true
    }

    // TODO this will get called on every keystroke
    // should track last value and only notify if changed
    func textViewDidChange(_ textView: UITextView) {
        guard let closure = self.didChangeMention else { return }
        guard let range = self.mentionRange else { closure(nil); return }
        guard let text = textView.attributedText else { closure(nil); return }
        let string = text.attributedSubstring(from: range).string
        closure(string)
    }

    func clear() {
        self.mentionRange = nil
        self.didChangeMention?("")
    }

    var didChangeMention: ((String?) -> Void)?

    // Called when setting the delegate, so that attributes in the delegate don't have to be redefined elsewhere.
    func styleTextView(textView: UITextView) {
        textView.font = self.font
        textView.text = self.placeholder
        textView.textColor = self.placeholderColor
        textView.typingAttributes = self.fontAttributes
    }

    var didBeginEditing: ((UITextView) -> Void)?
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.didBeginEditing?(textView)
        guard let placeholder = placeholder else { return }
        if let text = textView.text, text == placeholder {
            textView.text = ""
            textView.textColor = self.color
            textView.typingAttributes = self.fontAttributes
        }
    }
    
    var didEndEditing: ((UITextView) -> Void)?

    func textViewDidEndEditing(_ textView: UITextView) {
        self.didEndEditing?(textView)
        guard let placeholder = placeholder else { return }
        if let text = textView.text, text.isEmpty {
            textView.text = placeholder
            textView.textColor = self.placeholderColor
        }
    }
}
