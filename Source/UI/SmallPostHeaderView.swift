//
//  SmallPostHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 6/17/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class SmallPostHeaderView: UIView {

    private var identity: Identity?

    private lazy var avatarButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self,action: #selector(didTapAvatarButton), for: .touchUpInside)
        button.isSkeletonable = true
        return button
    }()

    private lazy var nameButton: UIButton = {
        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self,action: #selector(didTapAvatarButton), for: .touchUpInside)
        button.setTitleColor(.secondaryText, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont.smallPost.bigHeading
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        button.clipsToBounds = true
        button.isSkeletonable = true
        return button
    }()

    private let dateLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        label.font = UIFont.smallPost.header
        label.numberOfLines = 1
        label.textColor = .secondaryText
        label.isSkeletonable = true
        return label
    }()

    convenience init(with keyValue: KeyValue) {
        self.init()
        update(with: keyValue)
    }

    init() {
        super.init(frame: CGRect.zero)
        self.useAutoLayout()

        Layout.fillLeft(of: self,
                        with: self.avatarButton,
                        insets: UIEdgeInsets(top: 10, left: 10, bottom: -10, right: 0),
                        respectSafeArea: false)
        self.avatarButton.constrainSize(to: 20)

        self.addSubview(self.nameButton)
        self.nameButton.constrainTop(toTopOf: self.avatarButton)
        self.nameButton.constrainLeading(toTrailingOf: self.avatarButton, constant: 5)
        self.nameButton.constrainTrailingToSuperview(constant: -10)

        //self.addSubview(self.dateLabel)
        //self.dateLabel.pinTop(toBottomOf: self.nameButton)
        //self.dateLabel.constrainLeading(to: self.nameButton)
        //self.dateLabel.constrainTrailing(to: self.nameButton)

        self.nameButton.constrainHeight(to: 20)
        //self.dateLabel.constrainHeight(to: 10)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.avatarButton.round()
    }

    func update(with keyValue: KeyValue) {
        let identity = keyValue.value.author
        self.identity = identity

        let about = keyValue.metadata.author.about
        let name = about?.nameOrIdentity ?? keyValue.value.author
        self.nameButton.setTitle(name, for: .normal)
        self.avatarButton.setImage(for: about)

        self.dateLabel.text = keyValue.timestampString
    }

    @objc private func didTapAvatarButton() {
        guard let identity = self.identity else { return }
        Analytics.shared.trackDidTapButton(buttonName: "avatar")
        AppController.shared.pushViewController(for: .about, with: identity)
    }
}

// MARK:- Date formatting

fileprivate extension KeyValue {

    var timestampString: String {
        let ud = self.userDate
        let day = ud.todayYesterdayDayOfWeekOrNumberOfDaysAgo
        let time = ud.timeOfDay
        let text = Text.atDayTime.text(["day": day, "time": time])
        return text.prefix(1).capitalized + text.dropFirst()
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
