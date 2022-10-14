//
//  ThreadReplyPaginatedDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/8/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol ThreadReplyPaginatedTableViewDataSourceDelegate: AnyObject {
    
    func threadReplyView(view: ThreadReplyView, didLoad message: Message)
}

class ThreadReplyPaginatedTableViewDataSource: MessagePaginatedTableViewDataSource {

    weak var delegate: ThreadReplyPaginatedTableViewDataSourceDelegate?
    
    var expandedPosts = Set<Identifier>()
    
    override func loadMessage(_ message: Message, in cell: MessageTableViewCell) {
        let threadReplyView = cell.messageView as! ThreadReplyView
        threadReplyView.textIsExpanded = self.expandedPosts.contains(message.key)
        super.loadMessage(message, in: cell)
        self.delegate?.threadReplyView(view: threadReplyView, didLoad: message)
    }
    
    override func cell(at indexPath: IndexPath, for type: ContentType) -> MessageTableViewCell {
        let view = ThreadReplyView()
        view.textIsExpanded = false
        let cell = MessageTableViewCell(for: .post, with: view)
        return cell
    }
    
    override func emptyCell() -> MessageTableViewCell {
        // TODO Make thread repky view skeletonable
        let view = ThreadReplyView()
        view.textIsExpanded = false
        return MessageTableViewCell(for: .post, with: view)
    }
}
