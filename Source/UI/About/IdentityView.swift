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
    private var headerOffset = CGFloat.zero

    @State
    private var contentOffset = CGFloat.zero

    @State
    private var maxSize = CGSize.zero

    @State
    private var minSize = CGSize.zero

    private var showAlert: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { _ in
            errorMessage = nil
            AppController.shared.dismiss(animated: true)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                IdentityViewHeader(identity: identity, about: about, extendedHeader: extendedHeader)
                    .background {
                        IdentityViewHeader(identity: identity, about: about, extendedHeader: true)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .background {
                                GeometryReader { geometryProxy in
                                    Color.clear.preference(key: ExtendedSizePreferenceKey.self, value: geometryProxy.size)
                                }
                            }
                            .onPreferenceChange(ExtendedSizePreferenceKey.self) { newSize in
                                maxSize = newSize
                            }
                    }
                    .background {
                        IdentityViewHeader(identity: identity, about: about, extendedHeader: false)
                            .hidden()
                            .background {
                                GeometryReader { geometryProxy in
                                    Color.clear.preference(key: CollapsedSizePreferenceKey.self, value: geometryProxy.size)
                                }
                            }
                            .onPreferenceChange(CollapsedSizePreferenceKey.self) { newSize in
                                minSize = newSize
                            }
                    }
                    .zIndex(extendedHeader ? 500 : 1000)
                    .offset(y: headerOffset)
                MessageListView(strategy: NoHopFeedAlgorithm(identity: identity))
                    .background(Color.appBg)
                    .zIndex(extendedHeader ? 1000 : 500)
                    .offset(y: contentOffset)
                Spacer()
                    .frame(height: contentOffset)
            }
        }
        .background(Color.appBg)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            guard minSize.height > 0, maxSize.height > 0 else {
                return
            }
            let offset = value
            if maxSize.height + offset > minSize.height {
                if !extendedHeader {
                    extendedHeader = true
                    contentOffset = 0
                }
                headerOffset = -offset

            } else {
                if extendedHeader {
                    extendedHeader = false
                    contentOffset = maxSize.height - minSize.height
                }
                headerOffset = -offset
            }
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

fileprivate struct ExtendedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

fileprivate struct CollapsedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

fileprivate struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }

    typealias Value = CGFloat
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
