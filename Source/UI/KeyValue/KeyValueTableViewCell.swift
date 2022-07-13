//
//  KeyValueTableViewCell.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValueTableViewCell: UITableViewCell, KeyValueUpdateable {

    let type: ContentType
    let keyValueView: KeyValueView

    init(for type: ContentType, with view: KeyValueView? = nil, height: CGFloat? = nil, readableWidth: Bool = false) {
        self.type = type
        self.keyValueView = view ?? KeyValueView.for(type)
        super.init(style: .default, reuseIdentifier: type.reuseIdentifier)
        self.constrainKeyValueViewToContentView(height, readableWidth: readableWidth)
        self.selectionStyle = .none
        backgroundColor = .clear
        self.keyValueView.showAnimatedSkeleton()
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constrainKeyValueViewToContentView(_ height: CGFloat? = nil, readableWidth: Bool) {
        keyValueView.useAutoLayout()
        contentView.addSubview(keyValueView)
        let leadingAnchor = readableWidth ? layoutMarginsGuide.leadingAnchor : leadingAnchor
        let trailingAnchor = readableWidth ? layoutMarginsGuide.trailingAnchor : trailingAnchor
        NSLayoutConstraint.activate([
            keyValueView.topAnchor.constraint(equalTo: contentView.topAnchor),
            keyValueView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
//            keyValueView.centerXAnchor.constraint(equalTo: readableContentGuide.centerXAnchor),
//            keyValueView.widthAnchor.constraint(equalTo: readableContentGuide.widthAnchor),
            keyValueView.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyValueView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        guard let height = height else { return }
        let constraint = self.keyValueView.heightAnchor.constraint(lessThanOrEqualToConstant: height)
        constraint.priority = .defaultHigh
        constraint.isActive = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        keyValueView.reset()
    }

    // MARK: KeyValueUpdateable

    func update(with keyValue: KeyValue) {
        self.keyValueView.update(with: keyValue)
    }
}
