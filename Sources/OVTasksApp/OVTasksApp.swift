import SwiftUI

@main
struct OVTasksApp: App {
    @StateObject private var preview = PreviewStore()
    @StateObject private var clickUp = ClickUpConnectionStore()

    var body: some Scene {
        MenuBarExtra("OV Tasks", systemImage: "checklist") {
            DashboardView()
                .environmentObject(preview)
                .environmentObject(clickUp)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreviewSettingsView()
                .environmentObject(preview)
        }
    }
}
