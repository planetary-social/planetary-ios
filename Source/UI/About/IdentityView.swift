//
//  IdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 23/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct IdentityView: View {

    var identity: Identity

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var about: About?

    @State
    private var errorMessage: String?

    @State
    private var extendedHeader = true

    @State
    private var oldScrollViewOffset = ScrollViewOffsetPreferenceKey.defaultValue

    private var showAlert: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { _ in
            errorMessage = nil
            AppController.shared.dismiss(animated: true)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(
                        key: ScrollViewOffsetPreferenceKey.self,
                        value: offset
                    )
                    .frame(height: 0)
                    .border(Color.red)
                }.frame(height: 0)
                MessageListView(strategy: NoHopFeedAlgorithm(identity: identity)) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top, spacing: 18) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                                        startPoint: .bottomLeading,
                                        endPoint: .topTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                                .frame(width: 92, height: 92)
                                .overlay(
                                    ImageMetadataView(metadata: about?.image)
                                        .cornerRadius(99)
                                        .frame(width: 87, height: 87)
                                        .scaledToFill()
                                )
                                .onTapGesture {
                                    guard let image = about?.image else {
                                        return
                                    }
                                    AppController.shared.open(string: image.link)
                                }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(about?.nameOrIdentity ?? identity)
                                    .foregroundColor(Color.primaryTxt)
                                    .font(.system(size: 20, weight: .semibold))
                                HStack {
                                    Text(identity.prefix(7))
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.secondaryTxt)
                                }
                                RelationshipView(identity: identity)
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        if extendedHeader {
                            if let bio = about?.description {
                                Text(bio.parseMarkdown())
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.primaryTxt)
                                    .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                                    .lineLimit(10)
                            } else if about == nil {
                                Text(String.loremIpsum(1))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.primaryTxt)
                                    .redacted(reason: .placeholder)
                                    .padding(EdgeInsets(top: 0, leading: 18, bottom: 9, trailing: 18))
                            }
                            HashtagSliderView(identity: identity)
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 9, trailing: 0))
                            SocialStatsView(identity: identity)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.profileBgTop, Color.profileBgBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                }
            }
        }
        .background(Color.appBg)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            if value < 0 {
                if oldScrollViewOffset >= 0 {
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            } else {
                if oldScrollViewOffset < 0 {
                    withAnimation(.easeIn(duration: 0.1)) {
                        extendedHeader.toggle()
                    }
                }
            }
            oldScrollViewOffset = value
        }
        .navigationTitle(Localized.profile.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                IdentityShareView(identity: identity)
                IdentityOptionsView(identity: identity, name: about?.name)
            }
        }
        .alert(isPresented: showAlert) {
            Alert(title: Localized.error.view, message: SwiftUI.Text(errorMessage ?? ""))
        }
        .onPreferenceChange(OffsetKey.self) {
            extendedHeader = ($0 ?? 0) < 143
        }
        .task {
            Task.detached { [identity] in
                let bot = await botRepository.current
                do {
                    let result = try await bot.about(identity: identity)
                    await MainActor.run {
                        about = result
                    }
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

fileprivate struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }

    typealias Value = CGFloat
}

fileprivate struct OffsetKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            IdentityView(identity: .null)
                .environmentObject(BotRepository.shared)
        }
        .preferredColorScheme(.light)

        NavigationView {
            IdentityView(identity: .null)
                .environmentObject(BotRepository.shared)
        }
        .preferredColorScheme(.dark)
    }
}
