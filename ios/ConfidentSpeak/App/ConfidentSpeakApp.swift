import SwiftUI

@main
struct ConfidentSpeakApp: App {
    private let database: AppDatabase

    init() {
        do {
            database = try AppDatabase.makeShared()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(database: database)
        }
    }
}
