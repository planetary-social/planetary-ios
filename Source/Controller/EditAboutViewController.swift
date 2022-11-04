//
//  EditAboutViewController.swift
//  FBTT
//
//  Created by Christoph on 5/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import CrashReporting

class EditAboutViewController: ContentViewController, Saveable, SaveableDelegate {

    // MARK: Data

    // Private storage of the initial About and any mutated
    // version after `save()` is called.
    private var _about: About
    var about: About { self._about }

    // MARK: Views

    private lazy var aboutView: EditAboutView = {
        let view = EditAboutView()
        view.delegate = self
        return view
    }()

    // MARK: Lifecycle

    init(with about: About? = nil) {
        self._about = about ?? About()
        let title: Localized = about == nil ? .createProfile : .editProfile
        super.init(title: title)
        self.aboutView.update(with: self._about)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addDismissBarButtonItem()
        Layout.fill(view: self.view, with: self.aboutView, respectSafeArea: false)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.for(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Edit About")
        Analytics.shared.trackDidShowScreen(screenName: "edit_about")
        self.aboutView.becomeFirstResponder()
    }

    // MARK: Saveable

    var isReadyToSave: Bool {
        self.aboutView.isReadyToSave
    }

    var saveCompletion: SaveCompletion?

    @objc func save() {
        Analytics.shared.trackDidTapButton(buttonName: "save")
        self.aboutView.resignFirstResponders()
        let name = self.aboutView.nameView.text
        let description = self.aboutView.bioView.text
        self._about = about.mutatedCopy(name: name, description: description)
        self.saveCompletion?(self)
    }

    // MARK: SaveableDelegate

    func saveable(_ saveable: Saveable, isReadyToSave: Bool) {
        self.navigationItem.rightBarButtonItem?.isEnabled = isReadyToSave
    }
}
