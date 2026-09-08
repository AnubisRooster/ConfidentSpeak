import SwiftUI

struct DayListView: View {
    @StateObject private var viewModel: DayListViewModel
    let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        _viewModel = StateObject(wrappedValue: DayListViewModel(database: database))
    }

    var body: some View {
        List(viewModel.days) { day in
            NavigationLink(value: day) {
                DayRow(day: day, isCompleted: viewModel.isCompleted(day))
            }
        }
        .navigationTitle("14-Day Program")
        .navigationDestination(for: ProgramDay.self) { day in
            DayDetailView(day: day, database: database)
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct DayRow: View {
    let day: ProgramDay
    let isCompleted: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(day.id): \(day.title)")
                    .font(.headline)
                Text(day.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DayListView(database: .preview())
    }
}
