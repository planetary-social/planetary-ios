//
//  NewMesssageView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct NewMesssageView: View {

    var message: Message

    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                ImageMetadataView(metadata: message.metadata.author.about?.image)
                    .cornerRadius(99)
                    .frame(width: 24, height: 24)
                    .scaledToFill()
                if let name = message.metadata.author.about?.nameOrIdentity {
                    Text("\(name) posted")
                }
            }
            .padding(10)
            Divider().background(Color(hex: "#a68782").opacity(0.15))
            Text(message.content.post?.text.parseMarkdown() ?? "This is not a post")
                .foregroundColor(Color.primaryTxt)
                .lineLimit(5)
                .padding(15)
            if let blob = message.content.post?.anyBlobs.first {
                ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
                    .aspectRatio(1, contentMode: .fill)
                    .onTapGesture {
                        AppController.shared.open(string: blob.identifier)
                    }
            }
            HStack {
                Text("Post a reply").foregroundColor(Color.primaryTxt).padding(8).frame(maxWidth: .infinity, idealHeight: 35).background(Color(hex: "#F4EBEA")).cornerRadius(18)
            }.padding(15)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#fff8f7"), Color(hex: "#fdf7f6")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
    }
}

struct NewMesssageView_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post(text: "Hello")
        let content = Content(from: post)
        let value = MessageValue(
            author: .null,
            content: content,
            hash: "",
            previous: nil,
            sequence: 0,
            signature: .null,
            claimedTimestamp: 0
        )
        let message = Message(
            key: .null,
            value: value,
            timestamp: 0
        )
        NewMesssageView(message: message).preferredColorScheme(.light)

    }
}
