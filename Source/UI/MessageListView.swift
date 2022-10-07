//
//  MessageListView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

let sampleMessage = Message(
    key: "%12345",
    value: MessageValue(
        author: "@4Wxraodifldsjf=.ed25519",
        content: Content(
            from: Post(text: "Hello, world")
        ),
        hash: "akldsjfa",
        previous: nil,
        sequence: 0,
        signature: "%alksdjfadsfi",
        claimedTimestamp: 345
    ),
    timestamp: 356,
    receivedSeq: 0,
    hashedKey: nil,
    offChain: false
)

struct MessageListView: View {
    @State var messages: [Message]
    @State var isLoading = false
    
    var body: some View {
        InfiniteList(
            data: $messages,
            isLoading: $isLoading
        ) {
            isLoading = true
            Task.detached {
                await Task.sleep(2000000000)
                let nextMessageIndex = messages.count
                for i in nextMessageIndex..<nextMessageIndex + 10 {
                    messages.append(
                        Message(
                            key: "%\(i)",
                            value: MessageValue(
                                author: "@4Wxraodifldsjf=.ed25519",
                                content: Content(
                                    from: Post(text: "Hello, world")
                                ),
                                hash: "akldsjfa",
                                previous: nil,
                                sequence: 0,
                                signature: "%alksdjfadsfi",
                                claimedTimestamp: 345
                            ),
                            timestamp: 356,
                            receivedSeq: 0,
                            hashedKey: nil,
                            offChain: false
                        )
                    )
                }
                isLoading = false
            }
        } content: { message in
            MessageView(message: message)
        }
    }
}

struct MessageListView_Previews: PreviewProvider {
    
    static var previews: some View {
        MessageListView(messages: [
            sampleMessage
        ])
    }
}
