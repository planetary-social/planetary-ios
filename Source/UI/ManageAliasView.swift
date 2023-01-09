//
//  ManageAliasView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct RoomAlias: Identifiable {
    var id: Int64
    var aliasURL: URL
    var string: String {
        aliasURL.absoluteString
    }
    var roomID: Int64?
    var authorID: Int64
    
    var alias: String {
        var components = string.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: ".")
        return components.joined(separator: ".")
    }
}

// A view model for the RoomListView
@MainActor protocol ManageAliasViewModel: ObservableObject {
    
    associatedtype RegistrationViewModelType: AddAliasViewModel
    
    /// A list of rooms the user is a member of.
    var aliases: [RoomAlias] { get }
    
    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get set }
    
    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }
    
    var registrationViewModel: RegistrationViewModelType { get }
    
    func deleteAliases(at: IndexSet)
    
    /// Tells the controller that the user wants to open the given room.
    func open(_ alias: RoomAlias)
    
    /// Called when the user dismisses the shown error message. Should clear `errorMessage`.
    func didDismissError()
    
    /// Called when the user pulls to refresh the view.
    func refresh()
}

struct LoadingOverlay: View {
    
    @Binding var message: String?
    
    var body: some View {
        VStack {
            Spacer()
            if let loadingMessage = message {
                VStack {
                    PeerConnectionAnimationView(peerCount: 5)
                    Text(loadingMessage)
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
}

/// Shows a list of room servers and allows the user to add and remove them.
struct ManageAliasView<ViewModel>: View where ViewModel: ManageAliasViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    @State var newAliasString = ""
    
    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }
    
    var body: some View {
        List {
            // Help Text
            Section {} footer: {
                Localized.Alias.introText.view
                    .foregroundColor(.secondaryText)
                    .font(.subheadline)
                    .padding(.top, 4)
            }
            
            // Joined Rooms
            if !viewModel.aliases.isEmpty {
                Section {
                    ForEach(viewModel.aliases) { alias in
                        Button {
                            viewModel.open(alias)
                        } label: {
                            HStack {
                                Text(alias.string.replacingOccurrences(of: "https://", with: ""))
                                Spacer()
                                Button {
                                    UIPasteboard.general.setValue(
                                        alias.aliasURL,
                                        forPasteboardType: UTType.url.identifier
                                    )
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .padding(9)
                                .background(Color.menuBorderColor.clipShape(Circle()))
                            }
                        }
                        
                        .foregroundColor(.mainText)
                        .listRowBackground(Color.cardBackground)
                    }
                    .onDelete(perform: { viewModel.deleteAliases(at: $0) })
                } header: {
                    Localized.Alias.aliases.view
                        .foregroundColor(.secondaryText)
                        .font(.body.smallCaps())
                }
            }
            
            // Add Rooms
            Section {
                NavigationLink("Register a new alias") {
                    AddAliasView(viewModel: viewModel.registrationViewModel)
                }
                .listRowBackground(Color.cardBackground)
            }
        }
        .disabled(viewModel.loadingMessage?.isEmpty == false)
        .overlay(LoadingOverlay(message: $viewModel.loadingMessage))
        .alert(isPresented: showAlert) {
            // Error alert
            Alert(
                title: Localized.error.view,
                message: Text(viewModel.errorMessage ?? "")
            )
        }
        .refreshable {
            viewModel.refresh()
        }
        .onAppear {
            viewModel.refresh()
        }
        .navigationBarTitle(Localized.Alias.roomAliases.text, displayMode: .inline)
        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
        }
        .accentColor(.primaryAction)
    }
}

// MARK: - Previews
// swiftlint:disable force_unwrapping

fileprivate class PreviewViewModel: ManageAliasViewModel {
    
    @Published var aliases: [RoomAlias]
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    var registrationViewModel: AddAliasPreviewViewModel {
        AddAliasPreviewViewModel(rooms: [])
    }
    
    init(aliases: [RoomAlias]) {
        self.aliases = aliases
        UITableView.appearance().backgroundColor = UIColor.appBackground
    }
    
    func deleteAliases(at indexes: IndexSet) {
        indexes.forEach { aliases.remove(at: $0) }
    }
    
    func refresh() {}
    
    func open(_ alias: RoomAlias) {}
    
    func didDismissError() {
        errorMessage = nil
    }
}

struct ManageAliasView_Previews: PreviewProvider {
    
    static let aliases = [
        RoomAlias(id: 0, aliasURL: URL(string: "https://bob.civic.room")!, roomID: 1, authorID: 1)
    ]
    
    static var previews: some View {
        NavigationView {
            ManageAliasView(viewModel: PreviewViewModel(aliases: []))
        }
        .preferredColorScheme(.dark)
        
        NavigationView {
            ManageAliasView(viewModel: PreviewViewModel(aliases: aliases))
        }
        .preferredColorScheme(.dark)
        
        NavigationView {
            ManageAliasView(viewModel: PreviewViewModel(aliases: aliases))
        }
        .preferredColorScheme(.light)
    }
}
