//
//  RawMessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 19/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A view model for the RawMessageView
@MainActor protocol RawMessageViewModel: ObservableObject {

    /// The raw message to display in screen
    var rawMessage: String? { get }

    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get }

    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }

    /// Called when the user dismisses the shown error message. Should clear `errorMessage`.
    func didDismissError()

    /// Called when the user taps on the Cancel button
    func didDismiss()
}

struct RawMessageView<ViewModel>: View where ViewModel: RawMessageViewModel {
    @ObservedObject var viewModel: ViewModel

    /// A loading overlay that displays the `loadingMessage` from the view model.
    private var loadingIndicator: some View {
        VStack {
            Spacer()
            if showProgress, let loadingMessage = viewModel.loadingMessage {
                VStack {
                    PeerConnectionAnimationView(peerCount: 5)
                    SwiftUI.Text(loadingMessage)
                        .foregroundColor(.mainText)
                }
                .padding(16)
                .cornerRadius(8)
                .background(Color.cardBackground.cornerRadius(8))
            } else {
                EmptyView()
            }
            Spacer()
        }
    }

    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }

    private var showProgress: Bool {
        viewModel.loadingMessage?.isEmpty == false
    }
    
    var body: some View {
        ZStack {
            if let source = viewModel.rawMessage {
                SelectableText(text: source)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.didDismiss()
                } label: {
                    SwiftUI.Text(Text.cancel.text)
                }
            }
        }
        .navigationTitle(Text.messageSource.text)
        .disabled(showProgress)
        .overlay(loadingIndicator)
        .alert(isPresented: showAlert) {
            Alert(
                title: Text.error.view,
                message: SwiftUI.Text(viewModel.errorMessage ?? "")
            )
        }
    }
}

fileprivate class PreviewViewModel: RawMessageViewModel {

    @Published var rawMessage: String?

    @Published var loadingMessage: String? = "Loading..."

    @Published var errorMessage: String?

    init(_ rawMessage: String) {
        self.rawMessage = rawMessage
    }

    func didDismissError() {}

    func didDismiss() {}
}

struct RawMessageView_Previews: PreviewProvider {
    // swiftlint:disable line_length
    static let source = """
    {
        "key": "%6Ic4dzY/mBxVXdSNwSIyQ1TqBp+FKsY+tLnumBPdxaA=.sha256",
        "value": {
            "previous": "%d8Iyl2ZVHwdyiAAeIvbDCVXVeLXPYajI7IRHgC0/rf4=.sha256",
            "author": "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519",
            "sequence": 31,
            "timestamp": 1549386935492,
            "hash": "sha256",
            "content": {
                "type": "vote",
                "channel": "ssb-server",
                "vote": {
                    "link": "%OoBqCtaYm6ayBQqCVlHi66vsWfvaK5+t98aqsXlRyZU=.sha256",
                    "value": 1,
                    "expression": "Like"
                }
            },
            "signature": "8caUJ2gqJ4DOnfD2gDFpyWbseUeNMhzX/tr8j2IR7xSG3GcyDG8GCAyrv7YkOTu2PnEM6fdLb1jNrit+YVYlDg==.sig.ed25519"
        },
        "timestamp": 1546962907954.0059
    }
    """
    // swiftlint:enable line_length

    static var previews: some View {
        NavigationView {
            RawMessageView(viewModel: PreviewViewModel(source))
        }
        .preferredColorScheme(.dark)

        NavigationView {
            RawMessageView(viewModel: PreviewViewModel(source))
        }
        .preferredColorScheme(.light)
    }
}
