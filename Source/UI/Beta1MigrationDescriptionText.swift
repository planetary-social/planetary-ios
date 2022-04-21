//
//  Beta1MigrationDescriptionText.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A text block that has a piece of tappable text inside describing the Beta1 Migration.
/// The way I made the "start using Planetary" text tappable is really hacked together, but
/// I didn't spend a lot of time making it nice because there is a much simpler way to do this
/// in iOS 15 which we should be moving to soon.
struct Beta1MigrationDescriptionText<ViewModel>: View where ViewModel: Beta1MigrationViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    /// The height for the wrapped UITextView
    @State private var textLabelHeight: CGFloat = 0
    
    var textColor = Color("subheadlineText")
    var textUIColor = UIColor(named: "subheadlineText")
    
    var startUsingPlanetaryString: NSMutableAttributedString {
        NSMutableAttributedString(
            string: Text.beta1StartUsingPlanetary.text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: textUIColor as Any
            ]
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            if viewModel.progress >= 0.995 {
                Text.beta1MigrationComplete.view
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                    .foregroundColor(textColor)
            } else {
                
                Text.beta1MigrationPleaseLeaveAppOpen.view
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                
                TextLabelWithHyperlink(
                    tintColor: UIColor.linkColor,
                    attributedString: startUsingPlanetaryString,
                    height: $textLabelHeight,
                    hyperLinkItems: [
                        .init(subText: Text.startUsingPlanetary.text)
                    ],
                    openLink: { _ in
                        viewModel.buttonPressed()
                    }
                )
                .frame(height: textLabelHeight)
                
                Text.beta1Disclaimers.view
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                    .foregroundColor(textColor)
            }
        }
        .padding(0)
    }
}

/// A UITextView wrapped for SwiftUI that can embed tappable `HyperLinkItem`s.
/// This is messy, but it can be done with Markdown in iOS 15 so I'm not spending much time making it nice.
/// https://stackoverflow.com/a/67614913/982195
fileprivate struct TextLabelWithHyperlink: UIViewRepresentable {
    
    /// https://stackoverflow.com/a/60441078/982195
    class HeightUITextView: UITextView {
        @Binding var height: CGFloat
        
        init(height: Binding<CGFloat>) {
            _height = height
            super.init(frame: .zero, textContainer: nil)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            let newSize = sizeThatFits(CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude))
            if height != newSize.height {
                height = newSize.height
            }
        }
    }
    
    @State var tintColor: UIColor
    
    @State var hyperLinkItems: Set<HyperLinkItem>
    
    @Binding var height: CGFloat
    
    private var attributedString: NSMutableAttributedString
    
    private var openLink: (HyperLinkItem) -> Void
    
    init (
        tintColor: UIColor,
        attributedString: NSMutableAttributedString,
        height: Binding<CGFloat>,
        hyperLinkItems: Set<HyperLinkItem>,
        openLink: @escaping (HyperLinkItem) -> Void
    ) {
        self.tintColor = tintColor
        self.hyperLinkItems = hyperLinkItems
        self.attributedString = attributedString
        self.openLink = openLink
        self._height = height
    }
    
    func makeUIView(context: Context) -> HeightUITextView {
        let textView = HeightUITextView(height: $height)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.isEditable = false
        textView.isSelectable = false
        textView.tintColor = self.tintColor
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        return textView
    }
    
    func updateUIView(_ uiView: HeightUITextView, context: Context) {
        
        for item in hyperLinkItems {
            let subText = item.subText
            let link = item.subText.replacingOccurrences(of: " ", with: "_")
            // swiftlint:disable legacy_objc_type
            let range = (attributedString.string as NSString).range(of: subText)
            // swiftlint:enable legacy_objc_type

            attributedString.addAttribute(.link, value: String(format: "https://%@", link), range: range)
            attributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: 1, range: range)
        }
        
        uiView.attributedText = attributedString
        
        // Compute the desired height for the content
        let fixedWidth = uiView.frame.size.width
        let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))

        DispatchQueue.main.async {
            self.height = newSize.height
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextLabelWithHyperlink
        
        init( parent: TextLabelWithHyperlink ) {
            self.parent = parent
        }
        
        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            
            let strPlain = url.absoluteString
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "_", with: " ")
            
            if let tappedLink = parent.hyperLinkItems.first(where: { $0.subText == strPlain }) {
                parent.openLink(tappedLink)
            }
            
            return false
        }
    }
}

fileprivate struct HyperLinkItem: Hashable {
    
    let subText: String
    let attributes: [NSAttributedString.Key: Any]?
    
    init (
        subText: String,
        attributes: [NSAttributedString.Key: Any]? = nil
    ) {
        self.subText = subText
        self.attributes = attributes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(subText)
    }
    
    static func == (lhs: HyperLinkItem, rhs: HyperLinkItem) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

fileprivate class PreviewViewModel: Beta1MigrationViewModel {
    func buttonPressed() {}
    var progress: Float
    
    init(progress: Float) {
        self.progress = progress
    }
}

struct Beta1MigrationDescriptionText_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Beta1MigrationDescriptionText(viewModel: PreviewViewModel(progress: 0.5))
                .frame(maxWidth: 287)
                .previewLayout(.sizeThatFits)
            
            Beta1MigrationDescriptionText(viewModel: PreviewViewModel(progress: 0.5))
                .frame(maxWidth: 287)
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
            
            Beta1MigrationDescriptionText(viewModel: PreviewViewModel(progress: 1.0))
                .frame(maxWidth: 287)
                .previewLayout(.sizeThatFits)
        }
        .background(Color("appBackground"))
    }
}
