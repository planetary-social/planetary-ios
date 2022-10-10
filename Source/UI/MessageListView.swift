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

protocol MessageListViewModel: InfiniteList {
    associatedtype CachedCollection = [Message]
    var cache: [Message] { get }
    var isLoading: Bool { get set }
    func loadMore()
}

struct MessageListView<ViewModel>: View where ViewModel: MessageListViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        InfiniteListView(dataSource: viewModel) { message in
            MessageView(message: message as! Message)
        }
    }
}

fileprivate class PreviewViewModel: MessageListViewModel {
    @Published var cache = [sampleMessage]
    
    @Published var isLoading = false
    
    func loadMore() {
        isLoading = true
        Task.detached {
            try await Task.sleep(nanoseconds: 2_000_000)
            let nextMessageIndex = self.cache.count
            for i in nextMessageIndex..<nextMessageIndex + 10 {
                self.cache.append(
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
            self.isLoading = false
        }
    }
}

struct MessageListView_Previews: PreviewProvider {
    
    static var previews: some View {
        MessageListView(viewModel: PreviewViewModel())
    }
}
