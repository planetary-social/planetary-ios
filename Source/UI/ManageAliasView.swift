//
//  ManageAliasView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct RoomAlias: Identifiable {
    var id: Int
    var aliasURL: URL
    var string: String {
        aliasURL.absoluteString
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
    
    /// Tries to add a room to the database from an invitation link or multiserver address string.
    func addAlias(from: String)
    
    /// Tells the coordinator that the user wants to open the given room.
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
                    SwiftUI.Text(loadingMessage)
                        .foregroundColor(Color("mainText"))
                }
                .padding(16)
                .cornerRadius(8)
                .background(Color("cardBackground").cornerRadius(8))
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
            // Joined Rooms
            if !viewModel.aliases.isEmpty {
                Section {
                    ForEach(viewModel.aliases) { alias in
                        Button {
                            viewModel.open(alias)
                        } label: {
                            SwiftUI.Text(alias.string)
                        }
                        .foregroundColor(Color("mainText"))
                        .listRowBackground(Color("cardBackground"))
                    }
                    .onDelete(perform: { viewModel.deleteAliases(at: $0) })
                } header: {
                    Text.Alias.aliases.view
                        .foregroundColor(Color("secondaryText"))
                        .font(.body.smallCaps())
                }
            }
            
            // Add Rooms
            Section {
                NavigationLink("Register a new alias") {
                    AddAliasView(viewModel: viewModel.registrationViewModel)
                }
                .listRowBackground(Color("cardBackground"))
            }
        }
        .disabled(viewModel.loadingMessage?.isEmpty == false)
        .overlay(LoadingOverlay(message: $viewModel.loadingMessage))
        .alert(isPresented: showAlert) {
            // Error alert
            Alert(
                title: Text.error.view,
                message: SwiftUI.Text(viewModel.errorMessage ?? "")
            )
        }
        .refreshable {
            viewModel.refresh()
        }
        .navigationBarTitle(Text.Alias.manageAliases.text, displayMode: .inline)
        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
        }
        .accentColor(Color("primaryAction"))
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
    
    func addAlias(from: String) {
        if let address = MultiserverAddress(string: from) {
            loadingMessage = "Registering alias..."
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.aliases.append(RoomAlias(id: 0, aliasURL: URL(string: "https://bob.civic.room")!))
                self.loadingMessage = nil
            }
        } else {
            errorMessage = "Error registering alias"
        }
    }
    
    func open(_ alias: RoomAlias) {}
    
    func didDismissError() {
        errorMessage = nil
    }
}

struct ManageAliasView_Previews: PreviewProvider {
    
    static let aliases = [
        RoomAlias(id: 0, aliasURL: URL(string: "https://bob.civic.room")!)
    ]
    
    static var previews: some View {
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
