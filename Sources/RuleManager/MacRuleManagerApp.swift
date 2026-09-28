import SwiftUI

@main
struct MacRuleManagerApp: App {
    @StateObject private var workspace = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup("Mac Rule Manager") {
            MainView()
                .environmentObject(workspace)
                .frame(minWidth: 900, minHeight: 650)
        }
    }
}
