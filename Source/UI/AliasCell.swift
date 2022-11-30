//
//  AliasCell.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit

class AliasCell: UIView {

    var aliases: [RoomAlias] = [] {
        didSet {
            layout()
        }
    }

    lazy var aliasStack: UIStackView = {
        let stack = UIStackView.forAutoLayout()
        stack.axis = .vertical
        stack.spacing = Layout.verticalSpacing
        return stack
    }()
    
    var zeroHeightConstraint: NSLayoutConstraint?
    
    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()
        let (_, _, bottom, _) = Layout.fill(view: self, with: aliasStack, insets: .default)
        bottom.priority = .required
        
        let separator = Layout.separatorView()
        Layout.fillBottom(of: self, with: separator)
        
        zeroHeightConstraint = heightAnchor.constraint(equalToConstant: 0)
        zeroHeightConstraint?.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func layout() {
        aliasStack.subviews.forEach { $0.removeFromSuperview() }
        
        zeroHeightConstraint?.isActive = aliases.isEmpty
        
        for alias in aliases {
            let urlString = alias.aliasURL.absoluteString.replacingOccurrences(of: "https://", with: "")
            
            let linkImage = NSTextAttachment()
            linkImage.image = UIImage(systemName: "link")?.withTintColor(.mainText)

            let aliasName = NSMutableAttributedString(string: urlString)
            aliasName.addAttributes([
                .foregroundColor: UIColor.primaryAction,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            
            let attributedString = NSMutableAttributedString()
            attributedString.append(NSAttributedString(attachment: linkImage))
            attributedString.append(NSAttributedString(string: " "))
            attributedString.append(aliasName)
            let label = UILabel.forAutoLayout()
            label.attributedText = attributedString
            
            let tapGesture = BindableGestureRecognizer {
                UIApplication.shared.open(alias.aliasURL)
            }
            label.isUserInteractionEnabled = true
            label.addGestureRecognizer(tapGesture)
            aliasStack.addArrangedSubview(label)
        }
    }
}

final class BindableGestureRecognizer: UITapGestureRecognizer {
    private var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc
    private func execute() {
        action()
    }
}
