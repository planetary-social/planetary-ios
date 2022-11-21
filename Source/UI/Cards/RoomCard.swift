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
    @ObservedObject var viewModel: RoomsOnboardingController
    
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
                if viewModel.selectedRoom != nil {
                    TextField("", text: $viewModel.alias)
                        .autocorrectionDisabled(true)
                        .placeholder(when: viewModel.alias.isEmpty) {
                            Text(Localized.Onboarding.typeYourAlias.text)
                                .foregroundColor(.secondaryText)
                        }
                        .onChange(of: viewModel.alias) { newValue in
                            viewModel.alias = newValue
                                .lowercased()
                                .filter("abcdefghijklmnopqrstuvwxyz0123456789-".contains)
                        }
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
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(uiImage: .warning)
                            Text(verbatim: errorMessage)
                                .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: 400, maxHeight: 100, alignment: .center)
        }
    }
}

fileprivate class PreviewViewModel: RoomsOnboardingController {
    
    init() {
        super.init(bot: FakeBot())
        self.selectedRoom = Room(
            identifier: "Planetary Alias",
            imageName: "icon-planetary-3",
            address: MultiserverAddress(
                keyID: "Planetary",
                host: "planetary.name",
                port: 8008
            )
        )
        self.errorMessage = Localized.Onboarding.aliasTaken.text
    }
}

// swiftlint:disable force_unwrapping
struct RoomCard_Previews: PreviewProvider {
    
    struct RoomCardContainer: View {
        var body: some View {
            let viewModel = PreviewViewModel()
            
            RoomCard(
                room: viewModel.selectedRoom!,
                viewModel: viewModel
            )
        }
    }
    
    static var previews: some View {
        RoomCardContainer()
            .padding(40)
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
