//
//  RoomListView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A view model for the RoomListView
@MainActor protocol RoomListViewModel: ObservableObject {
    
    /// A list of rooms the user is a member of.
    var rooms: [Room] { get }
    
    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get }
    
    /// An alert message that should be displayed when it is not nil
    var alertMessage: String? { get set }
    
    /// An alert title that should be displayed when it is not nil
    var alertMessageTitle: String? { get set }
    
    /// An error message that should be displayed when it is not nil
    func deleteRooms(at: IndexSet)
    
    /// Tries to add a room to the database from an invitation link or multiserver address string.
    func addRoom(from: String)
    
    /// Tells the coordinator that the user wants to open the given room.
    func open(_ room: Room)
    
    /// Called when the user dismisses the shown error message. Should clear `errorMessage`.
    func didDismissError()
    
    /// Called when the user pulls to refresh the view.
    func refresh()
    
    func joinPlanetaryRoom()
    
    var showJoinPlanetaryRoomButton: Bool { get }
}

/// Shows a list of room servers and allows the user to add and remove them.
struct RoomListView<ViewModel>: View where ViewModel: RoomListViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    @State var newRoomString = ""
    
    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.alertMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }
    
    private var showProgress: Bool {
        viewModel.loadingMessage != nil
    }
    
    /// A loading overlay that displays the `loadingMessage` from the view model.
    private var loadingIndicator: some View {
        VStack {
            Spacer()
            if showProgress, let loadingMessage = viewModel.loadingMessage {
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
    
    var body: some View {
        List {
            // Joined Rooms
            if !viewModel.rooms.isEmpty {
                Section {
                    ForEach(viewModel.rooms) { room in
                        Button {
                            viewModel.open(room)
                        } label: {
                            Text(room.address.host)
                        }
                        .foregroundColor(.mainText)
                        .listRowBackground(Color.cardBackground)
                    }
                    .onDelete(perform: { viewModel.deleteRooms(at: $0) })
                } header: {
                    Localized.ManageRelays.joinedRooms.view
                        .foregroundColor(.secondaryText)
                        .font(.body.smallCaps())
                }
            }
            
            // Add Rooms
            Section {
                HStack {
                    TextField("", text: $newRoomString)
                        .placeholder(when: newRoomString.isEmpty) {
                            Localized.addRoomAddressOrInvitation.view
                                .foregroundColor(.secondaryText)
                        }
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .onSubmit {
                            viewModel.addRoom(from: newRoomString)
                            newRoomString = ""
                        }
                    Button {
                        viewModel.addRoom(from: newRoomString)
                        newRoomString = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.primaryAction)
                    }
                    .disabled(newRoomString.isEmpty || showProgress)
                }
                .listRowBackground(Color.cardBackground)
            } header: {
                Localized.ManageRelays.addRooms.view
                    .foregroundColor(.secondaryText)
                    .font(.body.smallCaps())
            } footer: {
                Localized.ManageRelays.roomHelpText.view
                    .foregroundColor(.secondaryText)
                    .font(.subheadline)
                    .padding(.top, 4)
            }
            
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
        .disabled(showProgress)
        .overlay(loadingIndicator)
        .alert(isPresented: showAlert) {
            // Error alert
            Alert(
                title: Text(viewModel.alertMessageTitle ?? ""),
                message: Text(viewModel.alertMessage ?? "")
            )
        }
        .refreshable {
            viewModel.refresh()
        }
        .navigationBarTitle(Localized.ManageRelays.manageRooms.text, displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .accentColor(.primaryAction)
    }
}

// swiftlint:disable force_unwrapping

fileprivate class PreviewViewModel: RoomListViewModel {
    
    @Published var rooms: [Room]
    
    @Published var loadingMessage: String?
    
    @Published var alertMessage: String?
    
    @Published var alertMessageTitle: String?
    
    @Published var showJoinPlanetaryRoomButton = true
    
    init(rooms: [Room]) {
        self.rooms = rooms
        UITableView.appearance().backgroundColor = UIColor.appBackground
    }
    
    func deleteRooms(at indexes: IndexSet) {
        indexes.forEach { rooms.remove(at: $0) }
    }
    
    func refresh() {}
    
    func addRoom(from: String) {
        if let address = MultiserverAddress(string: from) {
            loadingMessage = "Joining room..."
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.rooms.append(Room(address: address))
                self.loadingMessage = nil
            }
        } else {
            alertMessage = "Error joining room"
        }
    }
    
    func open(_ room: Room) {}
    
    func didDismissError() {
        alertMessage = nil
    }
    
    func joinPlanetaryRoom() {}
}

struct RoomListView_Previews: PreviewProvider {
    
    static let rooms = [
        Room(address: MultiserverAddress(
            string: "net:test-room.planetary.social:8008~shs:bGo2yHoSjTFVYmZxPD9+AZM2LYnp6A/5WxHzezfDLls="
        )!)
    ]
    
    static var previews: some View {
        NavigationView {
            RoomListView(viewModel: PreviewViewModel(rooms: rooms))
        }
        .preferredColorScheme(.dark)
        
        NavigationView {
            RoomListView(viewModel: PreviewViewModel(rooms: rooms))
        }
        .preferredColorScheme(.light)
    }
}
