//
//  MessageList.swift
//  Planetary
//
//  Created by Martin Dutra on 18/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A scrollable list of messages
struct MessageList<DataSource>: View where DataSource: MessageDataSource {
    @ObservedObject
    var dataSource: DataSource

    var body: some View {
        InfiniteList(dataSource: dataSource) { message in
            if let message = message as? Message {
                MessageButton(message: message)
                    .id(message)
            }
        }
    }
}
