//
//  FloatingButton.swift
//  Planetary
//
//  Created by Martin Dutra on 2/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct FloatingButton<DataSource>: View where DataSource: MessageDataSource {

    var count: Int

    @ObservedObject
    var dataSource: DataSource

    var proxy: ScrollViewProxy?

    private var title: AttributedString {
        let countString = "\(count)"
        let arguments = ["count": countString]
        let string = count == 1 ? Localized.refreshSingular.text(arguments) : Localized.refreshPlural.text(arguments)
        var attributedString = AttributedString(string)
        if let range = attributedString.range(of: countString) {
            attributedString[range].font = .subheadline.bold()
        }
        return attributedString
    }
    
    var body: some View {
        Button {
            proxy?.scrollTo(dataSource.cache?.first, anchor: .top)
            Task {
                await dataSource.loadFromScratch()
            }
        } label: {
            if dataSource.isLoadingFromScratch {
                HStack(alignment: .center) {
                    ProgressView().tint(Color.white).frame(width: 18, height: 18)
                    Text(Localized.loading.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .background(
                    Rectangle()
                        .fill(LinearGradient.horizontalAccent)
                        .cornerRadius(17)
                )
            } else {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .background(
                        LinearGradient.horizontalAccent
                            .cornerRadius(17)
                    )
            }
        }
        .disabled(dataSource.isLoadingFromScratch)
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        .shadow(color: .buttonShadow, radius: 10, x: 0, y: 4)
        .offset(y: 10)
    }
}

struct FloatingButton_Previews: PreviewProvider {
    static var dataSource: StaticMessageDataSource {
        StaticMessageDataSource(messages: [])
    }
    static var loadingDataSource: StaticMessageDataSource {
        let dataSource = StaticMessageDataSource(messages: [])
        dataSource.isLoadingFromScratch = true
        return dataSource
    }
    static var previews: some View {
        VStack {
            FloatingButton(count: 1, dataSource: dataSource)
            FloatingButton(count: 2, dataSource: dataSource)
            FloatingButton(count: 1, dataSource: loadingDataSource)
        }
    }
}
