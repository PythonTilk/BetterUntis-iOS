//
//  BetterUntisApp.swift
//  BetterUntis
//
//  Created by Noel Burkhardt on 17.09.25.
//

import SwiftUI
import CoreData

@main
struct BetterUntisApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
