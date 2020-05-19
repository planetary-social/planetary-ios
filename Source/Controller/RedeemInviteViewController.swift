//
//  RedeemInviteViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 3/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class RedeemInviteViewController: UIViewController, Saveable, SaveableDelegate, UITextViewDelegate {
    
    var saveCompletion: SaveCompletion?
    
    lazy var tokenLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.text.detail
        label.text = Text.ManagePubs.pasteAddress.text.uppercased()
        return label
    }()
    
    lazy var tokenTextView: UITextView = {
        let view = UITextView.forAutoLayout()
        view.delegate = self
        view.backgroundColor = UIColor.background.default
        view.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        view.isEditable = true
        view.isScrollEnabled = false
        view.textColor = UIColor.text.default
        view.textContainerInset = .square(10)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        return view
    }()
    
    // MARK: Lifecycle
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = Text.redeemInvitation.text
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.for(self)
        
        self.view.backgroundColor = UIColor.groupTableViewBackground
        
        let spacer = Layout.addSpacerView(toTopOf: self.view, height: 58)
        var separator = Layout.addSeparator(southOf: spacer)
        
        Layout.fillSouth(of: separator, with: self.tokenTextView)
        
        self.view.addSubview(self.tokenLabel)
        self.tokenLabel.pinBottom(toTopOf: separator, constant: 8)
        self.tokenLabel.pinLeftToSuperview(constant: 12)
        self.tokenLabel.constrainHeight(to: 46)
        
        separator = Layout.addSeparator(southOf: self.tokenTextView)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tokenTextView.becomeFirstResponder()
    }
    
    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        self.saveable(self, isReadyToSave: self.isReadyToSave)
    }
    
    // MARK: Saveable

    var isReadyToSave: Bool {
        // TODO: Maybe validate if it is a valid invitation text
        return !self.tokenTextView.text.isEmpty
    }
    
    func save() {
        self.tokenTextView.resignFirstResponder()
        let redeemCode = self.tokenTextView.text!
        AppController.shared.showProgress()
        Bots.current.inviteRedeem(token: redeemCode) { [weak self] error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            AppController.shared.hideProgress()
            if let error = error {
                self?.alert(error: error)
            } else if let strongSelf = self {
                self?.saveCompletion?(strongSelf)
            }
        }
    }
    
    func saveable(_ saveable: Saveable, isReadyToSave: Bool) {
        self.navigationItem.rightBarButtonItem?.isEnabled = isReadyToSave
    }
    
}
