import SwiftUI

@main
struct OVTasksApp: App {
    @StateObject private var preview = PreviewStore()

    var body: some Scene {
        MenuBarExtra("OV Tasks — prévia", systemImage: "checklist") {
            DashboardView()
                .environmentObject(preview)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreviewSettingsView()
                .environmentObject(preview)
        }
    }
}
