//
//  IdentityButton.swift
//  Planetary
//
//  Created by Martin Dutra on 3/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct IdentityButton: View {
    var identityOrAbout: Either<Identity, About>
    var type: MessageView.`Type` = .compact

    init(identity: Identity, type: MessageView.`Type` = .compact) {
        self.init(identityOrAbout: .left(identity), type: type)
    }

    init(about: About, type: MessageView.`Type` = .compact) {
        self.init(identityOrAbout: .right(about), type: type)
    }

    init(identityOrAbout: Either<Identity, About>, type: MessageView.`Type` = .compact) {
        self.identityOrAbout = identityOrAbout
        self.type = type
    }

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Button {
            appController.open(identity: identityOrAbout.id)
        } label: {
            GoldenIdentityView(identityOrAbout: identityOrAbout)
        }
        .buttonStyle(IdentityButtonStyle())
    }
}

fileprivate struct IdentityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .compositingGroup()
            .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
            .shadow(
                color: .cardShadowBottom,
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
    }
}

struct IdentityButton_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            IdentityButton(identity: .null)
            IdentityButton(identity: .null)
                .preferredColorScheme(.dark)
        }
        .environmentObject(AppController.shared)
        .environmentObject(BotRepository.fake)
    }
}
