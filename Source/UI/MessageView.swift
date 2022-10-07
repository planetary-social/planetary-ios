//
//  MessageView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageView: View {
    
    var message: Message
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.black)
                SwiftUI.Text("Author")
                Spacer()
                Image(systemName: "ellipsis")
            }
            Color.black
                .frame(maxWidth: .infinity, maxHeight: 1)
            SwiftUI.Text(message.key)
            Color.black
                .frame(maxWidth: .infinity, maxHeight: 1)
            HStack {
                Spacer()
                Image(systemName: "arrowshape.turn.up.left")
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            MessageView(
                message: Message(
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
                        claimedTimestamp: 21345
                    ),
                    timestamp: 21356,
                    receivedSeq: 0,
                    hashedKey: nil,
                    offChain: false
                )
            )
        }
        .previewLayout(.sizeThatFits)
    }
}
