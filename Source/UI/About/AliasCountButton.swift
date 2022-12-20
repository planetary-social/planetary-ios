//
//  AliasCountButton.swift
//  Planetary
//
//  Created by Chad Sarles on 12/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct AliasCountButton: View {
    
    var aliases: [RoomAlias]
    var count: Int
    
    @State
    private var showingAliases = false
    
    private func aliasList(_ list: [RoomAlias], isPresented: Binding<Bool>) -> some View {
        NavigationView {
            AliasListView(aliases: aliases)
                .navigationTitle("\(aliases.count) \(Localized.Alias.aliases.text)" )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresented.wrappedValue = false
                        } label: {
                            Image.navIconDismiss
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    var body: some View {
        Button {
            showingAliases = true
        } label: {
            Text("+\(count)")
                .foregroundLinearGradient(
                    LinearGradient(
                        colors: [.aliasCountButtonTextGradientLeading, .aliasCountButtonTextGradientTrailing],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .font(.system(size: 10))
                .padding(4)
        }
        .background(Color.aliasCountButtonBackground)
        .cornerRadius(5)
        .sheet(isPresented: $showingAliases) {
            aliasList(aliases, isPresented: $showingAliases)
        }
    }
}

// swiftlint:disable force_unwrapping
struct AliasCountButton_Previews: PreviewProvider {
    static var count = 4
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
        ),
        RoomAlias(
            id: 3,
            aliasURL: URL(string: "https://rose.another.example")!,
            authorID: 1
        ),
        RoomAlias(
            id: 4,
            aliasURL: URL(string: "https://rose.yetanother.example")!,
            authorID: 1
        )
    ]
    static var previews: some View {
        Group {
            VStack {
                HStack {
                    Text("rose@techno.planetary")
                    AliasCountButton(aliases: aliases, count: 4)
                }
            }
            VStack {
                HStack {
                    Text("rose@techno.planetary")
                    AliasCountButton(aliases: aliases, count: 4)
                }
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
    }
}
