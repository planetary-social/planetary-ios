//
//  NetworkKeyViewController.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class NetworkKeyViewController: UIViewController {

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
        label.text = "If the text is red, then the root is invalid and likely not a base64 string."
        label.textColor = UIColor.lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    @available(*, deprecated)
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "Network Key"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.textView.delegate = self
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
        self.textView.text = UserDefaults.standard.networkKey?.string
        self.textView.contentOffset = CGPoint.zero
    }
}

extension NetworkKeyViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        if let key = NetworkKey(base64: textView.text) {
            textView.textColor = .black
            UserDefaults.standard.networkKey = key
        } else {
            textView.textColor = .red
        }
    }
}
