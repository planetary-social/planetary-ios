//
//  PostHeaderView.swift
//  FBTT
//
//  Created by Zef Houssney on 8/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class PostHeaderView: UIView {

    private var identity: Identity?

    private lazy var identityButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self, action: #selector(selectAboutIdentity), for: .touchUpInside)
        button.isSkeletonable = true
        return button
    }()

    private lazy var nameButton: UIButton = {
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self, action: #selector(selectAboutIdentity), for: .touchUpInside)
        button.setTitleColor(UIColor.text.default, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        button.isSkeletonable = true
        return button
    }()

    private var rightButtonContainer = UIView()

    private let dateLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 1
        label.textColor = UIColor.text.detail
        return label
    }()
    
    private let identifierLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.numberOfLines = 1
        label.textColor = UIColor.text.detail
        return label
    }()
    
    private let labelStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    var shouldShowTimestamp: Bool

    convenience init(with message: Message) {
        self.init()
        update(with: message)
    }
    
    /// Initializes the view with the given parameters.
    /// - Parameter showTimestamp: Will show the claimed post time if true, author id if false.
    init(showTimestamp: Bool = false, compactHeader: Bool = false) {
        self.shouldShowTimestamp = showTimestamp
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        let identityButtonSize = compactHeader ? Layout.contactThumbSize : Layout.profileThumbSize

        Layout.fillLeft(of: self, with: self.identityButton, respectSafeArea: false)
        self.identityButton.constrainSize(to: identityButtonSize)

        Layout.fillRight(of: self, with: self.rightButtonContainer, respectSafeArea: false)
        rightButtonContainer.widthAnchor.constraint(lessThanOrEqualToConstant: identityButtonSize).isActive = true

        addSubview(labelStackView)
        labelStackView.pinTopToSuperview()
        labelStackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        labelStackView.constrainHeight(to: identityButton)
        labelStackView.constrainLeading(toTrailingOf: self.identityButton, constant: Layout.horizontalSpacing)
        labelStackView.constrainTrailing(toLeadingOf: self.rightButtonContainer, constant: -6)
        labelStackView.addArrangedSubview(nameButton)

        if compactHeader {
            rightButtonContainer.isHidden = true
        } else if showTimestamp {
            labelStackView.addArrangedSubview(dateLabel)
            self.dateLabel.pinTop(toBottomOf: self.nameButton)
            self.dateLabel.constrainLeading(to: self.nameButton)
            self.dateLabel.constrainTrailing(toTrailingOf: self.nameButton)
        } else {
            labelStackView.addArrangedSubview(identifierLabel)
            self.identifierLabel.pinTop(toBottomOf: self.nameButton)
            self.identifierLabel.constrainLeading(to: self.nameButton)
            self.identifierLabel.constrainTrailing(toTrailingOf: self.nameButton, constant: 8)
        }
        
        self.nameButton.constrainHeight(to: 19)
        self.dateLabel.constrainHeight(to: 19)
        self.identifierLabel.constrainHeight(to: 19)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.identityButton.round()
    }

    func update(with message: Message) {
        let identity = message.author
        self.identity = identity

        let about = message.metadata.author.about
        let name = about?.name ?? message.author
        self.nameButton.setTitle(name, for: .normal)
        self.identityButton.setImage(for: about)
        self.dateLabel.text = message.timestampString
        if name != message.author {
            identifierLabel.text = String(identity.prefix(7))
            identifierLabel.isHidden = false
        } else {
            identifierLabel.isHidden = true
        }
        if let me = Bots.current.identity {
            let button: UIButton
            if identity.isCurrentUser {
                button = EditPostButton(post: message)
            } else {
                let relationship = Relationship(from: me, to: identity)
                button = RelationshipButton(with: relationship, name: name, content: message)
            }
            self.rightButtonContainer.subviews.forEach { $0.removeFromSuperview() }
            Layout.fill(view: self.rightButtonContainer, with: button)
        }

        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    @objc private func selectAboutIdentity() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}

// MARK: - Date formatting

fileprivate extension Message {

    var timestampString: String {
        let claimedDate = self.claimedDate
        let day = claimedDate.todayYesterdayDayOfWeekOrNumberOfDaysAgo
        let time = claimedDate.timeOfDay
        let text = Text.atDayTime.text(["day": day, "time": time])
        return text.prefix(1).capitalized + text.dropFirst()
    }
}

fileprivate extension Date {

    var todayYesterdayDayOfWeekOrNumberOfDaysAgo: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return Text.today.text }
        if calendar.isDateInYesterday(self) { return Text.yesterday.text }
        let components = calendar.dateComponents([.day], from: self, to: Date())
        let daysApart = components.day ?? -1
        if daysApart < 0 { return Text.future.text }
        if daysApart <= 7 { return DateFormatter.dayOfWeek.string(from: self) }
        return Text.daysAgo.text(["days": String(daysApart)])
    }

    var timeOfDay: String {
        DateFormatter.localizedString(from: self, dateStyle: .none, timeStyle: .short)
    }
}

fileprivate extension DateFormatter {

    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
