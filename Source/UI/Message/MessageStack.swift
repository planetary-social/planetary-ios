//
//  MessageStack.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A stack of messages. The primary purpose of this view is to be used in the Profile screen
/// inside the ScrollView defined in that screen. For most cases, consider using MessageList instead
/// that already integrates a ScrollView.
struct MessageStack<DataSource>: View where DataSource: MessageDataSource {
    @ObservedObject
    var dataSource: DataSource

    var body: some View {
        InfiniteStack(dataSource: dataSource) { message in
            if let message = message as? Message {
                MessageButton(message: message)
            }
        }
    }
}
