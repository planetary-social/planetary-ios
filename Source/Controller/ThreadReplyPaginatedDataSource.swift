//
//  ThreadReplyPaginatedDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/8/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol ThreadReplyPaginatedTableViewDataSourceDelegate: AnyObject {
    
    func threadReplyView(view: ThreadReplyView, didLoad keyValue: KeyValue)
}

class ThreadReplyPaginatedTableViewDataSource: KeyValuePaginatedTableViewDataSource {

    weak var delegate: ThreadReplyPaginatedTableViewDataSourceDelegate?
    
    var expandedPosts = Set<Identifier>()
    
    override func loadKeyValue(_ keyValue: KeyValue, in cell: KeyValueTableViewCell) {
        let threadReplyView = cell.keyValueView as! ThreadReplyView
        threadReplyView.textIsExpanded = self.expandedPosts.contains(keyValue.key)
        super.loadKeyValue(keyValue, in: cell)
        self.delegate?.threadReplyView(view: threadReplyView, didLoad: keyValue)
    }
    
    override func cell(at indexPath: IndexPath, for type: ContentType) -> KeyValueTableViewCell {
        let view = ThreadReplyView()
        view.textIsExpanded = false
        let cell = KeyValueTableViewCell(for: .post, with: view)
        return cell
    }
    
    override func emptyCell() -> KeyValueTableViewCell {
        // TODO Make thread repky view skeletonable
        let view = ThreadReplyView()
        view.textIsExpanded = false
        return KeyValueTableViewCell(for: .post, with: view)
    }
}
