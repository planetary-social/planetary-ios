//
//  MessageView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageView: View {
    
    // TODO: observe changes to message
    var message: Message
    
    var body: some View {
        VStack {
            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    Image(uiImage: VerseImages().missingAbout!)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(12)
                    Text(message.metadata.author.about?.nameOrIdentity ?? "error")
                        .lineLimit(1)
                        .foregroundColor(.white)
                    Text("posted")
                        .foregroundColor(Color(hex: "#8575A3"))
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color(hex: "#8575A3"))
                }
                Color(red: 32/255, green: 21/255, blue: 51/255)
                    .frame(maxWidth: .infinity, maxHeight: 0.5)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    if let postText = message.content.post?.text {
                        Text(try! AttributedString(markdown: message.content.post!.text))
                            .foregroundColor(.white)
                        
                    } else {
                        Text("type not supported yet")
                            .foregroundColor(.white)
                    }
                }
                .frame(minHeight: 50)
                Color(red: 32/255, green: 21/255, blue: 51/255)
                    .frame(maxWidth: .infinity, maxHeight: 0.5)
                    .edgesIgnoringSafeArea(.all)
                HStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrowshape.turn.up.left")
                        .resizable()
                        .scaledToFit()
                    Image(systemName: "bookmark")
                        .resizable()
                        .scaledToFit()
                    Image(systemName: "face.smiling")
                        .resizable()
                        .scaledToFit()
                }
                .frame(height: 18)
                .foregroundColor(Color(hex: "#8575A3"))
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#3D2961"), Color(hex: "#332251")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(20)
            )
        }
        .listRowBackground(
            Color.clear
        )
    }
}

struct MessageView_Previews: PreviewProvider {
    static var sampleMessage: Message = {
        var message = Message(
            key: "%12345",
            value: MessageValue(
                author: "@4Wxraodifldsjf=.ed25519",
                content: Content(
                    from: Post(text: "So awesome to be at the #Fastly conference as always! In awe with the atmosphere, details and content these people create!")
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
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(
                about: About(about: "@4Wxraodifldsjf=.ed25519", name: "Rossina")
            )
        )
        return message
    }()
    static var previews: some View {
        List {
            MessageView(message: sampleMessage)
            MessageView(message: sampleMessage)
        }
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
