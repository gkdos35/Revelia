// Signalfield/SignalfieldApp.swift

import SwiftUI

@main
struct SignalfieldApp: App {
    /// Campaign progress store — created once at app launch, shared via environment.
    @StateObject private var progressStore = ProgressStore()

    /// App-level settings (signal display mode, sound, first-launch flag).
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progressStore)
                .environmentObject(settingsStore)
        }
        .defaultSize(width: 600, height: 700)
    }
}
