import SwiftUI

struct ContentView: View {
    let database: AppDatabase

    var body: some View {
        TabView {
            NavigationStack {
                DayListView(database: database)
            }
            .tabItem { Label("Program", systemImage: "list.number") }

            NavigationStack {
                ProgramProgressView(database: database)
            }
            .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView(database: .preview())
}
