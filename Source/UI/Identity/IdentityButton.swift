//
//  IdentityButton.swift
//  Planetary
//
//  Created by Martin Dutra on 3/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays the a button with the information we have for an identity suitable for being used in a list
/// or grid.
///
/// The button opens IdentityView when tapped.
struct IdentityButton: View {
    var identityOrAbout: Either<Identity, About>
    var style = CardStyle.compact

    init(identity: Identity, style: CardStyle = .compact) {
        self.init(identityOrAbout: .left(identity), style: style)
    }

    init(about: About, style: CardStyle = .compact) {
        self.init(identityOrAbout: .right(about), style: style)
    }

    init(identityOrAbout: Either<Identity, About>, style: CardStyle = .compact) {
        self.identityOrAbout = identityOrAbout
        self.style = style
    }

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Button {
            appController.open(identity: identityOrAbout.id)
        } label: {
            IdentityCard(identityOrAbout: identityOrAbout, style: style)
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct IdentityButton_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            IdentityButton(identity: .null, style: .golden)
            IdentityButton(identity: .null, style: .golden)
                .preferredColorScheme(.dark)
        }
        .environmentObject(AppController.shared)
        .environmentObject(BotRepository.fake)
    }
}
