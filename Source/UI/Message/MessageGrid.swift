//
//  MessageGrid.swift
//  Planetary
//
//  Created by Martin Dutra on 27/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A scrollable grid of messages
struct MessageGrid<DataSource>: View where DataSource: MessageDataSource {
    @ObservedObject
    var dataSource: DataSource

    var body: some View {
        InfiniteGrid(dataSource: dataSource) { message in
            if let message = message as? Message {
                MessageButton(message: message)
            }
        }
    }
}
