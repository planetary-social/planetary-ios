//
//  BioView.swift
//  Planetary
//
//  Created by Martin Dutra on 15/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct BioView: View {

    var bio: String
    var lineLimit: Int? = nil
    
    var body: some View {
        Text(bio.parseMarkdown())
            .lineLimit(lineLimit)
            .font(.subheadline)
            .foregroundColor(.primaryTxt)
            .accentColor(.accentTxt)
            .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
    }
}
