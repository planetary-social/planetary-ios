//
//  RoomCard.swift
//  Planetary
//
//  Created by Chad Sarles on 11/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A view that represents a `Room`, containing an icon, title, subtitle,
///  `TextField`, and error message, with a gradient background color.
struct RoomCard: View {
    
    var room: Room
    var showTextInput: Bool
    var errorMessage: String?
   
    @State var alias = ""
    
    @FocusState private var nameIsFocused: Bool
    var backAction: ( () -> Void)
    var onSubmitAction: ( (String) -> Void)
    
    var body: some View {
        
        VStack(alignment: .trailing) {
            VStack(alignment: .leading) {
                HStack {
                    Image(uiImage: UIImage(named: room.imageName ?? "") ?? UIColor.black.image())
                        .resizable()
                        .background(.black)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .padding(.trailing, 5)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: room.identifier ?? "")
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.cardTitle)
                            .font(Font(UIFont.verse.contactName))
                        Text("\(Localized.Onboarding.yourAlias.text).\(room.address.host)") { string in
                            if let range = string.range(of: ".\(room.address.host)") {
                                string[range].foregroundColor = .secondaryText
                            }
                        }
                        .multilineTextAlignment(.leading)
                        .font(Font(UIFont.verse.peerCount))
                    }.multilineTextAlignment(.leading)
                }
                // Text Input
                if showTextInput {
                    TextField("", text: $alias)
                        .placeholder(when: alias.isEmpty) {
                            Text(Localized.Onboarding.typeYourAlias.text).foregroundColor(.secondaryText)
                        }
                        .focused($nameIsFocused)
                        .font(Font(UIFont.verse.pillButton))
                        .foregroundColor(.cardTextInputText)
                        .padding(7)
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.textInputBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(lineWidth: 1)
                                .fill(Color(.cardTextInputBorder))
                        )
                        .transition(
                            .move(edge: .bottom)
                            .combined(
                                with: AnyTransition.opacity.animation(
                                    .easeInOut(duration: 0.5)
                                )
                            )
                        )
                        .onSubmit {
                            nameIsFocused = false
                            onSubmitAction(alias)
                        }
                    // Error message
                    if let errorMessage {
                        Text(verbatim: errorMessage)
                            .font(Font(UIFont.verse.pillButton))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.highlightGradientLeading, .highlightGradientTrailing],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            // Card gradient
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            Color(.cardGradientTop),
                            Color(.cardGradientBottom)
                        ]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(15)
            .offset(x: 0, y: -5)
            // Bottom edge and shadows
            .background(
                Rectangle()
                    .fill(Color.cardThickness)
            )
            .cornerRadius(15)
            .offset(x: 0.0, y: -5)
            .padding(.bottom, -5)
            .shadow(color: Color.cardDropShadow, radius: 3, x: 0, y: 4)
            .shadow(color: Color.cardDropShadow, radius: 10, x: 0, y: 4)
            
            .frame(maxWidth: 400, maxHeight: 150, alignment: .center)
            Button("< Choose Alias Server") {
                backAction()
            }
            .foregroundColor(.cardTitle)
            .font(Font(UIFont.verse.peerCountBold))
            .opacity(showTextInput ? 1 : 0)
            .animation(
                Animation.easeInOut(duration: 0.5), value: showTextInput
            )
        }
    }
}

struct RoomCard_Previews: PreviewProvider {
    
    struct RoomCardContainer: View {
        
        @State var aliasTaken = false
        
        var body: some View {
            RoomCard(
                room: room,
                showTextInput: true,
                backAction: {
                    print("Back button tapped...")
                }, onSubmitAction: {_ in
                    print("Submitting...")
                }
            )
        }
    }
    static var room = Room(
        imageName: "icon-planetary-3",
        address: MultiserverAddress(
            keyID: "Planetary",
            host: "planetary.name",
            port: 8008
        )
    )
    
    static var previews: some View {
        RoomCardContainer()
    }
}

// https://betterprogramming.pub/ios-15-attributed-strings-in-swiftui-markdown-271204bec5c1
extension Text {
    init(_ string: String, configure: ((inout AttributedString) -> Void)) {
        var attributedString = AttributedString(string)
        configure(&attributedString)
        self.init(attributedString)
    }
}
