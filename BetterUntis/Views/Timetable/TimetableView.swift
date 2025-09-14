import SwiftUI
import Foundation

struct TimetableView: View {
    @EnvironmentObject var userRepository: UserRepository
    @StateObject private var timetableRepository = TimetableRepository()

    @State private var currentWeekStartDate: Date = Calendar.current.startOfWeek(for: Date())
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingDatePicker: Bool = false

    private var currentWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var weekRangeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Week navigation header
                weekNavigationHeader

                // Main content
                Group {
                    if isLoading {
                        loadingView
                    } else if let timetable = timetableRepository.currentTimetable {
                        WeekView(
                            timetable: timetable,
                            currentWeekStartDate: currentWeekStartDate
                        )
                    } else {
                        emptyStateView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Error message
                if let errorMessage = errorMessage {
                    errorView(errorMessage)
                }
            }
            .navigationTitle("Timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentWeekStartDate = Calendar.current.startOfWeek(for: Date())
                        }
                        loadTimetableForCurrentWeek()
                    }
                    .font(.caption)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { loadTimetableForCurrentWeek(forceRefresh: true) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(
                    selectedDate: currentWeekStartDate,
                    onDateSelected: { date in
                        currentWeekStartDate = Calendar.current.startOfWeek(for: date)
                        loadTimetableForCurrentWeek()
                    }
                )
            }
        }
        .onAppear {
            loadTimetableForCurrentWeek()
        }
        .onChange(of: userRepository.currentUser) { oldUser, newUser in
            if oldUser?.id != newUser?.id {
                loadTimetableForCurrentWeek()
            }
        }
    }

    // MARK: - Week Navigation Header
    private var weekNavigationHeader: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Spacer()

            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 2) {
                    Text(weekRangeString)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(Calendar.current.isDateInThisWeek(currentWeekStartDate) ? "This Week" : "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: nextWeek) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading timetable...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Timetable Data")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Pull to refresh or check your internet connection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { loadTimetableForCurrentWeek(forceRefresh: true) }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Helper Methods
    private var weekRangeString: String {
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStartDate)!
        let startMonth = weekRangeFormatter.string(from: currentWeekStartDate)
        let endMonth = weekRangeFormatter.string(from: endDate)

        if Calendar.current.component(.month, from: currentWeekStartDate) == Calendar.current.component(.month, from: endDate) {
            // Same month
            return "\(Calendar.current.component(.day, from: currentWeekStartDate)) - \(endMonth)"
        } else {
            // Different months
            return "\(startMonth) - \(endMonth)"
        }
    }

    private func previousWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentWeekStartDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStartDate)!
        }
        loadTimetableForCurrentWeek()
    }

    private func nextWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentWeekStartDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStartDate)!
        }
        loadTimetableForCurrentWeek()
    }

    private func loadTimetableForCurrentWeek(forceRefresh: Bool = false) {
        guard let user = userRepository.currentUser else {
            errorMessage = "No user selected"
            return
        }

        errorMessage = nil

        Task {
            await MainActor.run {
                isLoading = true
            }

            do {
                let weekEndDate = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStartDate)!

                try await timetableRepository.loadTimetable(
                    for: user,
                    startDate: currentWeekStartDate,
                    endDate: weekEndDate,
                    forceRefresh: forceRefresh
                )

                await MainActor.run {
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load timetable: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Date Picker View
struct DatePickerView: View {
    let selectedDate: Date
    let onDateSelected: (Date) -> Void

    @Environment(\.presentationMode) var presentationMode

    @State private var pickerDate: Date

    init(selectedDate: Date, onDateSelected: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $pickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()

                Spacer()
            }
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDateSelected(pickerDate)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Calendar Extensions
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func isDateInThisWeek(_ date: Date) -> Bool {
        return isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

#Preview {
    TimetableView()
        .environmentObject(UserRepository())
}