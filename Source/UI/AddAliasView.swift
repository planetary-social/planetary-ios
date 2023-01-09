//
//  AddAliasView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

@MainActor protocol AddAliasViewModel: ObservableObject {
    func register(_ desiredAlias: String, in room: Room?)
    var rooms: [Room] { get }
    
    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get set }
    
    /// An alert message that should be displayed when it is not nil
    var alertMessage: String? { get set }
    
    /// An alert title that should be displayed when it is not nil
    var alertMessageTitle: String? { get set }
    
    var shouldDismiss: Bool { get }
    
    func joinPlanetaryRoom()
    
    var showJoinPlanetaryRoomButton: Bool { get }
}

struct AddAliasView<ViewModel>: View where ViewModel: AddAliasViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    @State var newAliasString = ""
    @State var selectedRoom: Room?
    @State var desiredAlias: String = ""
    
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    
    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.alertMessage != nil
        } set: { _ in
            viewModel.alertMessage = nil
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("Room", selection: $selectedRoom) {
                        ForEach(viewModel.rooms) { room in
                            Text(room.address.host)
                                .foregroundColor(.mainText)
                                .tag(Optional(room))
                        }
                    }
                    
                    TextField("Alias (lowercase letters only)", text: $desiredAlias)
                        .foregroundColor(.mainText)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .onSubmit {
                            handleSubmit()
                        }
                    
                    if let selectedRoom = selectedRoom, desiredAlias.isEmpty == false {
                        HStack {
                            Text("https://\(desiredAlias).\(selectedRoom.address.host)")
                                .foregroundColor(.mainText)
                        }
                    }
                    
                    Button("Register") {
                        handleSubmit()
                    }
                    .foregroundColor(.primaryAction)
                }
                .listRowBackground(Color.cardBackground)
                .disabled(viewModel.rooms.isEmpty)
                
                if viewModel.showJoinPlanetaryRoomButton {
                    Section {
                        Button("Join Planetary Room") {
                            viewModel.joinPlanetaryRoom()
                        }
                        .foregroundColor(.primaryAction)
                        Text(
                            "Joining the official Planetary room server will allow to register aliases like " +
                            "yourname.planetary.name, and sync directly with others in the room."
                        )
                        .foregroundColor(.secondaryText)
                        .font(.subheadline)
                        .padding(.top, 4)
                        .lineLimit(5)
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
        }
        .navigationTitle("New Alias")
        .onChange(of: viewModel.shouldDismiss) { _ in presentationMode.wrappedValue.dismiss() }
        .overlay(LoadingOverlay(message: $viewModel.loadingMessage))
        .alert(isPresented: showAlert) {
            // Error alert
            Alert(
                title: Text(viewModel.alertMessageTitle ?? ""),
                message: Text(viewModel.alertMessage ?? "")
            )
        }
        .onAppear {
            if selectedRoom == nil {
                selectedRoom = viewModel.rooms.first
            }
        }
    }
    
    func handleSubmit() {
        viewModel.register(desiredAlias, in: selectedRoom)
    }
}

// MARK: - Previews

class AddAliasPreviewViewModel: AddAliasViewModel {
    var rooms: [Room] = []
    
    var loadingMessage: String?
    
    var alertMessage: String?
    
    var alertMessageTitle: String?
    
    var shouldDismiss = true

    init(rooms: [Room]) {
        self.rooms = rooms
    }
    
    func register(_ desiredAlias: String, in room: Room?) {}
    
    func joinPlanetaryRoom() {}
    
    var showJoinPlanetaryRoomButton = true
}

// swiftlint:disable force_unwrapping

struct AddAliasView_Previews: PreviewProvider {
    
    static let exampleRooms = [
        Room(
            address:
                MultiserverAddress(
                    string: "net:civic.love:8008~shs:fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM="
                )!
        ),
        Room(
            address:
                MultiserverAddress(
                    string: "net:hermies.club:8008~shs:fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM="
                )!
        ),
    ]
    
    static var previews: some View {
        NavigationView {
            AddAliasView(
                viewModel: AddAliasPreviewViewModel(rooms: exampleRooms)
            )
        }
        .preferredColorScheme(.dark)
        
        NavigationView {
            AddAliasView(
                viewModel: AddAliasPreviewViewModel(rooms: [])
            )
        }
    }
}
