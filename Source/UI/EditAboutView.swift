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
        self.backgroundColor = .cardBackground
        let spacer = Layout.addSpacerView(toTopOf: self)
        spacer.backgroundColor = .appBackground
        var separator = Layout.addSeparator(southOf: spacer)
        Layout.fillSouth(of: separator, with: self.nameView)
        separator = Layout.addSeparator(southOf: self.nameView)
        Layout.fillSouth(of: separator, with: self.bioView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with about: About) {
        self.nameView.textView.text = about.name
        self.bioView.textView.text = about.description
    }

    // MARK: First responding

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        self.nameView.becomeFirstResponder()
    }

    func resignFirstResponders() {
        self.nameView.textView.resignFirstResponder()
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
