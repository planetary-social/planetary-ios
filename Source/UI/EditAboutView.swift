//
//  EditAboutView.swift
//  FBTT
//
//  Created by Christoph on 5/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class EditAboutView: UIView, Saveable, UITextViewDelegate {

    lazy var nameView: EditValueView = {
        let view = EditValueView(label: .name)
        view.textView.delegate = self
        view.backgroundColor = .cardBackground
        view.textView.backgroundColor = .cardBackground
        return view
    }()

    lazy var bioView: EditValueView = {
        let view = EditValueView(label: .bio)
        view.textView.delegate = self
        view.backgroundColor = .cardBackground
        view.textView.backgroundColor = .cardBackground
        return view
    }()

    init() {
        super.init(frame: .zero)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.backgroundColor = .cardBackground
        let spacer = Layout.addSpacerView(toTopOf: self)
        spacer.backgroundColor = .appBackground
        let separator = Layout.addSeparator(southOf: spacer)
        Layout.fillSouth(of: separator, with: self.nameView)
        Layout.fillSouth(of: self.nameView, with: self.bioView)
        bioView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
    
    deinit {
         NotificationCenter.default.removeObserver(self)
       }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with about: About) {
        self.nameView.textView.text = about.name
        self.bioView.textView.text = about.description
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.keyboardFrameEnd else {
            return
        }
        let bottomOfTextView = bioView.convert(bioView.bounds, to: self).maxY
        let visibleArea = self.frame.height - keyboardFrame.height
        
        if bottomOfTextView > visibleArea {
            bioView.bottomConstraint?.constant = -keyboardFrame.height - Layout.verticalSpacing
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        bioView.bottomConstraint?.constant = -Layout.verticalSpacing
    }

    // MARK: First responding

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        self.nameView.becomeFirstResponder()
    }

    func resignFirstResponders() {
        self.nameView.textField.resignFirstResponder()
        self.bioView.textView.resignFirstResponder()
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        self.delegate?.saveable(self, isReadyToSave: self.isReadyToSave)
    }

    // MARK: Saveable

    var isReadyToSave: Bool {
        self.nameView.textView.text.isValidName
    }

    // TODO bah protocol requires this, wish is could be defaulted somehow
    var saveCompletion: ((Saveable) -> Void)?
    func save() {}

    weak var delegate: SaveableDelegate?
}
