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
            Button {
                if let contact = (message as! Message).content.contact {
                    appController.open(identity: contact.contact)
                } else {
                    appController.open(identifier: (message as! Message).id)
                }
            } label: {
                MessageView(message: message as! Message)
            }
            .buttonStyle(MessageButtonStyle())
        }
    }
}

