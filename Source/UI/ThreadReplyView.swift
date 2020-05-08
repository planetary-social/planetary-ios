//
//  ThreadReplyView.swift
//  Planetary
//
//  Created by Martin Dutra on 5/8/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class ThreadReplyView: PostCellView {

    override init() {
        super.init()
        self.truncationLimit = (over: 12, to: 8)
        Layout.addSeparator(toBottomOf: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
