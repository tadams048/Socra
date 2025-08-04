//
//  SocraApp.swift
//  Socra
//
//  Entry point with dependency injection.
//

import SwiftUI

@main
struct SocraApp: App {

    // Singleton dependency container
    @MainActor private var deps = AppDependencies.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deps.characterManager)   // 🟢 makes picker work
        }
    }
}
