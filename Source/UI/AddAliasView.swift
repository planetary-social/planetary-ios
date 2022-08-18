//
//  AddAliasView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/18/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol AddAliasViewModel: ObservableObject {
    func register(_ desiredAlias: String, in room: Room?)
    var rooms: [Room] { get }
    
    /// A loading message that should be displayed when it is not nil
    var loadingMessage: String? { get set }
    
    /// An error message that should be displayed when it is not nil
    var errorMessage: String? { get }
}

struct AddAliasView<ViewModel>: View where ViewModel: AddAliasViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    @State var newAliasString = ""
    @State var selectedRoom: Room?
    @State var desiredAlias: String = ""
    
    var body: some View {
        Form {
            Picker("Room", selection: $selectedRoom) {
                ForEach(viewModel.rooms) { room in
                    SwiftUI.Text(room.address.host).tag(Optional(room))
                }
            }
            TextField("Alias", text: $desiredAlias)
            Button("Register") {
                viewModel.register(desiredAlias, in: selectedRoom)
            }
        }
        .onAppear {
            selectedRoom = viewModel.rooms.first
        }
    }
}

// MARK: - Previews
// swiftlint:disable force_unwrapping

class AddAliasPreviewViewModel: AddAliasViewModel {
    var rooms: [Room] = []
    
    var loadingMessage: String?
    
    var errorMessage: String?
    
    init(rooms: [Room]) {
        self.rooms = rooms
    }
    
    func register(_ desiredAlias: String, in room: Room?) {
        
    }
}

struct AddAliasView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddAliasView(
                viewModel: AddAliasPreviewViewModel(
                    rooms: [
                        Room(address: MultiserverAddress(string: "net:civic.love:8008~shs:fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM=")!),
                        Room(address: MultiserverAddress(string: "net:hermies.club:8008~shs:fs26fDL6HzqnHoc2Ekq40AD0ETdf/D3Ze5oAIiEn8sM=")!),
                    ]
                )
            )
        }
    }
}
