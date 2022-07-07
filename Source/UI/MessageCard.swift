//
//  MessageCard.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit

class MessageCard: UIView {
    
    private let content: UIView
    
    let cardView: UIView = {
        let cardView = UIView()
        cardView.backgroundColor = .cardBackground
        cardView.roundCorners(radius: 20)
        return cardView
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    init(content: UIView) {
        self.content = content
        super.init(frame: content.frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        nil
    }
    
    func setUpViews() {
        backgroundColor = .cardBorder
        clipsToBounds = true
        Layout.fill(
            view: self,
            with: cardView,
            insets: UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10),
            respectSafeArea: false
        )
        Layout.fill(view: cardView, with: content, respectSafeArea: false)
    }
}
