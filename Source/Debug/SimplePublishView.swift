//
//  SimplePublishView.swift
//  FBTT
//
//  Created by Henry Bubert on 13.02.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class SimplePublishViewController: UIViewController {
    
    private let textView: UITextView = {
        let view = UITextView()
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.systemFont(ofSize: 14)
        return view
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.text = "warning: there is no undo"
        label.textColor = UIColor.lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "Publish"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
                                                                 target: self,
                                                                 action: #selector(publishButtonTouchUpInside))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.addSubviews()
        self.addConstraints()
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.update()
    }
    
    private func addSubviews() {
        self.view.addSubview(self.textView)
        self.view.addSubview(self.label)
    }
    
    private func addConstraints() {
        
        var view: UIView = self.textView
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 150),
            view.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 16),
            view.heightAnchor.constraint(equalToConstant: 250),
            view.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -16)
        ])
        
        view = self.label
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.textView.bottomAnchor, constant: 20),
            view.leftAnchor.constraint(equalTo: self.textView.leftAnchor),
            view.rightAnchor.constraint(equalTo: self.textView.rightAnchor)
        ])
    }
    
    private func update() {
        self.textView.text = "hello world"
        self.textView.contentOffset = CGPoint.zero
    }
    
    @objc func publishButtonTouchUpInside() {
        guard let t = self.textView.text else {
            self.label.text = "nohting to publish????"
            return
        }
        if t.count == 0 {
            self.label.text = "nohting to publish?"
            return
        }
        let p = Post(text: t)
        GoBot.shared.publish(p) {
            newMsg, error in
            DispatchQueue.main.async {
                self.textView.text = ""
                self.textView.endEditing(true)
                
                if let err = error {
                    Log.unexpected(.apiError, "err during publish")
                    Log.optional(err)
                    self.label.text = "warning: publish err: \(err.localizedDescription)"
                    return
                }
                Log.info("made new message: \(newMsg)")
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}
