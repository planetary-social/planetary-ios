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
import Combine

class PostTextEditorView: UIView {
    private let font = UIFont.systemFont(ofSize: 19, weight: .regular)
    private lazy var fontAttribute = [NSAttributedString.Key.font: self.font]

    private let mentionDelegate = MentionTextViewDelegate(
        font: UIFont.verse.newPost,
        color: UIColor.text.default
    )
    
    var textPublisher: AnyPublisher<NSAttributedString?, Never> = Just(nil).eraseToAnyPublisher()

    private lazy var sourceTextView: UITextView = {
        let view = UITextView.forPostsAndReplies()
        view.backgroundColor = .appBackground
        view.delegate = self.mentionDelegate
        view.font = font
        view.textColor = UIColor.text.default
        view.contentInset = UIEdgeInsets.default
        view.textContainerInset = UIEdgeInsets.defaultText
        return view
    }()

    private lazy var renderedTextView: UITextView = {
        let view = UITextView.forPostsAndReplies()
        view.backgroundColor = .cardBackground
        view.font = font
        view.textColor = UIColor.text.default
        view.alpha = 0
        view.contentInset = UIEdgeInsets.default
        view.textContainerInset = UIEdgeInsets.defaultText
        view.isEditable = false
        return view
    }()

    private lazy var menu: AboutsMenu = {
        let view = AboutsMenu()
        view.bottomSeparator.isHidden = true
        return view
    }()

    override var intrinsicContentSize: CGSize {
        sourceTextView.intrinsicContentSize
    }

    var attributedText: NSAttributedString {
        get {
            sourceTextView.attributedText
        }

        set {
            sourceTextView.attributedText = newValue
        }
    }

    var previewActive: Bool {
        get {
            renderedTextView.alpha > 0.9
        }

        set {
            if newValue {
                sourceTextView.isEditable = false
                renderedTextView.attributedText = sourceTextView.attributedText.string.decodeMarkdown()
                animateToPreview()
            } else {
                sourceTextView.isEditable = true
                renderedTextView.attributedText = nil
                animateToSourceView()
            }
        }
    }

    init() {
        super.init(frame: .zero)
        
        textPublisher = NotificationCenter.default
            .publisher(for: UITextView.textDidChangeNotification, object: sourceTextView)
            .map { ($0.object as? UITextView)?.attributedText }
            .eraseToAnyPublisher()

        useAutoLayout()
        backgroundColor = .cardBackground

        addSubview(sourceTextView)
        sourceTextView.pinTopToSuperview()
        sourceTextView.pinBottomToSuperviewBottom()
        sourceTextView.pinLeftToSuperview()
        sourceTextView.pinRightToSuperview()

        addSubview(renderedTextView)
        renderedTextView.pinTopToSuperview()
        renderedTextView.pinBottomToSuperviewBottom()
        renderedTextView.pinLeftToSuperview()
        renderedTextView.pinRightToSuperview()

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
            self.sourceTextView.replaceText(in: range, with: about.mention, attributes: self.fontAttribute)
            self.mentionDelegate.clear()
            self.menu.hide()
        }
    }

    override func becomeFirstResponder() -> Bool {
        sourceTextView.becomeFirstResponder()
    }
    
    func clear() {
        sourceTextView.text = ""
        renderedTextView.text = ""
    }

    private func animateToPreview() {
        UIView.animate(withDuration: 0.2, animations: {
            self.sourceTextView.alpha = 0
        },
        completion: { (_) in
            UIView.animate(withDuration: 0.2) {
                self.renderedTextView.alpha = 1
            }
        })
    }

    private func animateToSourceView() {
        UIView.animate(withDuration: 0.2, animations: {
            self.renderedTextView.alpha = 0
        },
        completion: { (_) in
            UIView.animate(withDuration: 0.2) {
                self.sourceTextView.alpha = 1
            }
        })
    }
}
