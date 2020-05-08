//
//  PostHeaderView.swift
//  FBTT
//
//  Created by Zef Houssney on 8/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class PostHeaderView: UIView {

    private var identity: Identity?

    private lazy var identityButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self,action: #selector(selectAboutIdentity), for: .touchUpInside)
        button.isSkeletonable = true
        return button
    }()

    private lazy var nameButton: UIButton = {
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self,action: #selector(selectAboutIdentity), for: .touchUpInside)
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

    convenience init(with keyValue: KeyValue) {
        self.init()
        update(with: keyValue)
    }

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        Layout.fillLeft(of: self, with: self.identityButton, respectSafeArea: false)
        self.identityButton.constrainSize(to: Layout.profileThumbSize)

        Layout.fillRight(of: self, with: self.rightButtonContainer, respectSafeArea: false)
        self.rightButtonContainer.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.profileThumbSize).isActive = true

        self.addSubview(self.nameButton)
        self.nameButton.pinTopToSuperview()
        self.nameButton.constrainLeading(toTrailingOf: self.identityButton, constant: Layout.horizontalSpacing)
        self.nameButton.constrainTrailing(toLeadingOf: self.rightButtonContainer, constant: -6)

        self.addSubview(self.dateLabel)
        self.dateLabel.pinTop(toBottomOf: self.nameButton)
        self.dateLabel.constrainLeading(to: self.nameButton)
        self.dateLabel.constrainTrailing(to: self.nameButton)

        self.nameButton.constrainHeight(to: 19)
        self.dateLabel.constrainHeight(to: 19)
        
        self.isSkeletonable = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.identityButton.round()
    }

    func update(with keyValue: KeyValue) {
        let identity = keyValue.value.author
        self.identity = identity

        let about = keyValue.metadata.author.about
        let name = about?.nameOrIdentity ?? keyValue.value.author
        self.nameButton.setTitle(name, for: .normal)
        self.identityButton.setImage(for: about)

        self.dateLabel.text = keyValue.timestampString

        if let me = Bots.current.identity {
            let button: UIButton
            if identity.isCurrentUser {
                button = EditPostButton(post: keyValue)
            } else {
                let relationship = Relationship(from: me, to: identity)
                button = RelationshipButton(with: relationship, name: name, content: keyValue)
            }
            self.rightButtonContainer.subviews.forEach { $0.removeFromSuperview() }
            Layout.fill(view: self.rightButtonContainer, with: button)
        }

        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    @objc private func selectAboutIdentity() {
        guard let identity = self.identity else { return }
        Analytics.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}

// MARK:- Date formatting

fileprivate extension KeyValue {

    var timestampString: String {
        let ud = self.userDate
        let day = ud.todayYesterdayDayOfWeekOrNumberOfDaysAgo
        let time = ud.timeOfDay
        return Text.atDayTime.text(["day": day, "time": time])
    }
}

fileprivate extension Date {

    var todayYesterdayDayOfWeekOrNumberOfDaysAgo: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self)         { return Text.today.text }
        if calendar.isDateInYesterday(self)     { return Text.yesterday.text }
        let components = calendar.dateComponents([.day], from: self, to: Date())
        let daysApart = components.day ?? -1
        if daysApart < 0                        { return Text.future.text }
        if daysApart <= 7                       { return DateFormatter.dayOfWeek.string(from: self) }
        return Text.daysAgo.text(["days": String(daysApart)])
    }

    var timeOfDay: String {
        return DateFormatter.localizedString(from: self, dateStyle: .none, timeStyle: .short)
    }
}

fileprivate extension DateFormatter {

    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
