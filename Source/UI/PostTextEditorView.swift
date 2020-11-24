//
//  MarkdownTextView.swift
//  Planetary
//
//  Created by Marcel Kummer on 17.11.20.
//  Copyright © 2020 Marcel Kummer. All rights reserved.
//

import Foundation
import Down
import UIKit

class PostTextEditorView: UIView {
    private let font = UIFont.systemFont(ofSize: 19, weight: .regular)
    private lazy var fontAttribute = [NSAttributedString.Key.font: self.font]

    private let mentionDelegate = MentionTextViewDelegate(font: UIFont.verse.newPost,
                                                          color: UIColor.text.default)

    private lazy var textView: UITextView = {
        let view = UITextView.forPostsAndReplies()
        view.backgroundColor = .cardBackground
        view.delegate = self.mentionDelegate
        view.font = font
        view.textColor = UIColor.text.default
        return view
    }()

    private lazy var menu: AboutsMenu = {
        let view = AboutsMenu()
        view.bottomSeparator.isHidden = true
        return view
    }()

    // This property holds the Markdown source "code" *only* while the rendered preview is shown. This way it also implicitly tells if the preview is currently active.
    private var sourceBuffer: NSAttributedString?

    var attributedText: NSAttributedString {
        get {
            return sourceBuffer ?? textView.attributedText
        }

        set {
            textView.attributedText = newValue
            sourceBuffer = nil
        }
    }

    var previewActive: Bool {
        get {
            return sourceBuffer != nil
        }

        set {
            if newValue {
                textView.isEditable = false
                sourceBuffer = textView.attributedText
                textView.attributedText = sourceBuffer!.string.decodeMarkdown()
            } else {
                textView.attributedText = sourceBuffer
                sourceBuffer = nil
                textView.isEditable = true
            }
        }
    }

    init() {
        super.init(frame: .zero)

        useAutoLayout()
        backgroundColor = .appBackground

        addSubview(textView)
        textView.pinTopToSuperview()
        textView.pinBottomToSuperviewBottom()
        textView.pinLeftToSuperview()
        textView.pinRightToSuperview()

        addSubview(menu)
        menu.pinBottomToSuperviewBottom()
        menu.constrainWidth(to: self)

        addActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addActions() {
        mentionDelegate.didChangeMention = { [unowned self] string in
            self.menu.filter(by: string)
        }

        menu.didSelectAbout = { [unowned self] about in
            guard let range = self.mentionDelegate.mentionRange else { return }
            self.textView.replaceText(in: range, with: about.mention, attributes: self.fontAttribute)
            self.mentionDelegate.clear()
            self.menu.hide()
        }
    }

    override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
    }
}
