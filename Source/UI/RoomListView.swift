//
//  RoomListView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

@MainActor protocol RoomListViewModel: ObservableObject {
    var rooms: [Room] { get }
    var loadingMessage: String? { get }
    var errorMessage: String? { get }
    func deleteRooms(at: IndexSet)
    func add(room: String)
    func didDismissError()
}

struct RoomListView<ViewModel>: View where ViewModel: RoomListViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    @State var newRoomString = ""
    
    private var showAlert: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { _ in
            viewModel.didDismissError()
        }
    }
    
    private var showProgress: Bool {
        viewModel.loadingMessage != nil
    }
    
    private var loadingIndicator: some View {
        VStack {
            Spacer()
            if showProgress {
                VStack {
                    PeerConnectionAnimationView(peerCount: 5)
                    SwiftUI.Text(viewModel.loadingMessage!)
                }
                .padding(16)
                .cornerRadius(8)
                .background(Color.white.cornerRadius(8))
            } else {
                EmptyView()
            }
            Spacer()
        }
    }
    
    var body: some View {
        List {
            ForEach(viewModel.rooms) { room in
                HStack {
                    SwiftUI.Text(room.address.host)
                }
            }
            .onDelete(perform: { viewModel.deleteRooms(at: $0) })
            
            HStack {
                TextField("add a room", text: $newRoomString)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onSubmit {
                        viewModel.add(room: newRoomString)
                        newRoomString = ""
                    }
                Button {
                    viewModel.add(room: newRoomString)
                    newRoomString = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newRoomString.isEmpty || showProgress)
            }
        }
        .disabled(showProgress)
        .overlay(loadingIndicator)
        .alert(isPresented: showAlert) {
            Alert(
                title: SwiftUI.Text("Failed Joining Room"),
                message: SwiftUI.Text(viewModel.errorMessage!)
            )
        }
    }
}

// swiftlint:disable force_unwrapping

fileprivate class PreviewViewModel: RoomListViewModel {
    
    @Published var rooms: [Room]
    
    @Published var loadingMessage: String?
    
    @Published var errorMessage: String?
    
    init(rooms: [Room]) {
        self.rooms = rooms
    }
    
    func deleteRooms(at indexes: IndexSet) {
        indexes.forEach { rooms.remove(at: $0) }
    }
    
    func add(room: String) {
        if let address = MultiserverAddress(string: room) {
            loadingMessage = "Joining room..."
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.rooms.append(Room(address: address))
                self.loadingMessage = nil
            }
        } else {
            errorMessage = "Error joining room"
        }
    }
    
    func didDismissError() {
        errorMessage = nil
    }
}

struct RoomListView_Previews: PreviewProvider {
    
    static let rooms = [
        Room(address: MultiserverAddress(
            string: "net:192.168.1.131:8008~shs:bGo2yHoSjTFVYmZxPD9+AZM2LYnp6A/5WxHzezfDLls="
        )!)
    ]
    
    static var previews: some View {
        RoomListView(viewModel: PreviewViewModel(rooms: rooms))
    }
}
