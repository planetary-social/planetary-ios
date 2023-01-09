//
//  SearchResultsTab.swift
//  Planetary
//
//  Created by Martin Dutra on 6/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct SearchResultsTab: View {

    var sections: [SearchResultsSection]

    @Binding
    var selectedSection: SearchResultsSection

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(sections) { section in
                Button {
                    $selectedSection.wrappedValue = section
                } label: {
                    if $selectedSection.wrappedValue == section {
                        section.label
                            .foregroundColor(.white)
                            .background(Color.selectedtabBg)
                            .cornerRadius(20)
                    } else {
                        section.label
                            .foregroundColor(.secondaryTxt)
                    }
                }
                .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 15))
            }
        }
        .padding(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.tabBgTop, .tabBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .zIndex(1)
        .compositingGroup()
        .shadow(color: .tabBorderBottom, radius: 0, x: 0, y: 0.5)
        .shadow(color: .tabShadowBottom, radius: 10, x: 0, y: 4)
    }
}

struct SearchResultsTab_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                SearchResultsTab(
                    sections: SearchResultsSection.allCases,
                    selectedSection: Binding { SearchResultsSection.all } set: { _ in }
                )
                SearchResultsTab(
                    sections: SearchResultsSection.allCases,
                    selectedSection: Binding { SearchResultsSection.people } set: { _ in }
                )
            }
            VStack(spacing: 20) {
                SearchResultsTab(
                    sections: SearchResultsSection.allCases,
                    selectedSection: Binding { SearchResultsSection.all } set: { _ in }
                )
                SearchResultsTab(
                    sections: SearchResultsSection.allCases,
                    selectedSection: Binding { SearchResultsSection.people } set: { _ in }
                )
            }
            .preferredColorScheme(.dark)
        }
        .frame(maxHeight: .infinity)
        .background(Color.appBg)
    }
}
