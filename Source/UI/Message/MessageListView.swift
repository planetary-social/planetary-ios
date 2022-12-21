//
//  MessageListView.swift
//  Planetary
//
//  Created by Martin Dutra on 18/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageListView<DataSource>: View where DataSource: MessageList {
    @ObservedObject
    var dataSource: DataSource

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        InfiniteListView(dataSource: dataSource) { message in
            if let message = message as? Message {
                MessageButton(message: message)
            }
        }
    }
}
