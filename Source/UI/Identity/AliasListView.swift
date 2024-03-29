//
//  AliasListView.swift
//  Planetary
//
//  Created by Chad Sarles on 12/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct AliasListView: View {
    
    var aliases: [RoomAlias]
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 1) {
                Divider()
                ForEach(aliases) { alias in
                    HStack {
                        Text(alias.alias)
                        Button {
                            UIPasteboard.general.string = alias.string
                        }
                        label: {
                            Text(Localized.allCapsCopy.text)
                                .foregroundLinearGradient(
                                    LinearGradient.horizontalAccent
                                )
                                .font(.system(size: 10))
                                .padding(4)
                        }
                    .background(Color.aliasCountButtonBackground)
                    .cornerRadius(5)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    Color.cardBackground
                )
            }
        }
        .background(Color.appBg)
    }
}

// swiftlint:disable force_unwrapping
struct AliasListView_Previews: PreviewProvider {

    static var aliases = [
        RoomAlias(
            id: 1,
            aliasURL: URL(string: "https://rose.techno.planetary")!,
            authorID: 1
        ),
        RoomAlias(
            id: 2,
            aliasURL: URL(string: "https://rose.fungi.planetary")!,
            authorID: 1
        )
    ]

    static var previews: some View {
        Group {
            VStack {
                AliasListView(aliases: aliases)
            }
            VStack {
                AliasListView(aliases: aliases)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
