import SwiftUI
import Foundation

struct RoomFinderView: View {
    @EnvironmentObject var userRepository: UserRepository
    @StateObject private var roomFinderRepository = RoomFinderRepository()

    @State private var selectedDate: Date = Date()
    @State private var selectedTimeSlot: TimeSlot?
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let timeSlots: [TimeSlot] = [
        TimeSlot(start: "08:00", end: "09:30", id: 1),
        TimeSlot(start: "09:45", end: "11:15", id: 2),
        TimeSlot(start: "11:30", end: "13:00", id: 3),
        TimeSlot(start: "14:00", end: "15:30", id: 4),
        TimeSlot(start: "15:45", end: "17:15", id: 5),
        TimeSlot(start: "17:30", end: "19:00", id: 6)
    ]

    var filteredRooms: [RoomAvailability] {
        roomFinderRepository.availableRooms.filter { room in
            searchText.isEmpty || room.room.name.localizedCaseInsensitiveContains(searchText) ||
            room.room.longName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter section
                filterSection

                // Results
                Group {
                    if isLoading {
                        loadingView
                    } else if filteredRooms.isEmpty && !roomFinderRepository.availableRooms.isEmpty {
                        noResultsView
                    } else if filteredRooms.isEmpty {
                        emptyStateView
                    } else {
                        roomsList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Error message
                if let errorMessage = errorMessage {
                    errorView(errorMessage)
                }
            }
            .navigationTitle("RoomFinder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: searchRooms) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(isLoading || selectedTimeSlot == nil)
                }
            }
        }
        .onAppear {
            if selectedTimeSlot == nil {
                selectedTimeSlot = currentTimeSlot
            }
        }
    }

    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 16) {
            // Date picker
            DatePicker(
                "Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(CompactDatePickerStyle())

            // Time slot selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Slot")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(timeSlots, id: \.id) { timeSlot in
                            TimeSlotButton(
                                timeSlot: timeSlot,
                                isSelected: selectedTimeSlot?.id == timeSlot.id,
                                action: { selectedTimeSlot = timeSlot }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search rooms...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Time Slot Button
    struct TimeSlotButton: View {
        let timeSlot: TimeSlot
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(timeSlot.start)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(timeSlot.end)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Rooms List
    private var roomsList: some View {
        List(filteredRooms, id: \.room.id) { roomAvailability in
            RoomAvailabilityRow(roomAvailability: roomAvailability)
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching for available rooms...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("Find Free Rooms")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Select a date and time slot to see available rooms.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if selectedTimeSlot != nil {
                Button("Search Rooms") {
                    searchRooms()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Rooms Found")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("No rooms match your search criteria.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button("Clear Search") {
                searchText = ""
            }
            .font(.subheadline)
            .foregroundColor(.blue)
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

    // MARK: - Helper Properties
    private var currentTimeSlot: TimeSlot? {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeString = String(format: "%02d:%02d", currentHour, currentMinute)

        return timeSlots.first { timeSlot in
            timeSlot.start <= currentTimeString && currentTimeString < timeSlot.end
        } ?? timeSlots.first { $0.start > currentTimeString }
    }

    // MARK: - Methods
    private func searchRooms() {
        guard let timeSlot = selectedTimeSlot,
              let user = userRepository.currentUser else {
            return
        }

        errorMessage = nil

        Task {
            await MainActor.run {
                isLoading = true
            }

            do {
                try await roomFinderRepository.findAvailableRooms(
                    for: user,
                    date: selectedDate,
                    timeSlot: timeSlot
                )

                await MainActor.run {
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to search rooms: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Room Availability Row
struct RoomAvailabilityRow: View {
    let roomAvailability: RoomAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roomAvailability.room.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !roomAvailability.room.longName.isEmpty {
                        Text(roomAvailability.room.longName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                availabilityBadge
            }

            if let building = roomAvailability.room.building, !building.isEmpty {
                Label(building, systemImage: "building")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Availability timeline
            if !roomAvailability.timeline.isEmpty {
                availabilityTimeline
            }
        }
        .padding(.vertical, 4)
    }

    private var availabilityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(roomAvailability.isAvailable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(roomAvailability.isAvailable ? "Available" : "Occupied")
                .font(.caption)
                .foregroundColor(roomAvailability.isAvailable ? .green : .red)
        }
    }

    private var availabilityTimeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(roomAvailability.timeline, id: \.timeSlot) { availability in
                    Rectangle()
                        .fill(availability.isAvailable ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                        .frame(width: 30, height: 20)
                        .cornerRadius(2)
                        .overlay(
                            Text(availability.timeSlot)
                                .font(.system(size: 8))
                                .foregroundColor(.primary)
                        )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Supporting Types
struct TimeSlot: Identifiable, Equatable {
    let start: String
    let end: String
    let id: Int
}

struct RoomAvailability {
    let room: Room
    let isAvailable: Bool
    let timeline: [TimeSlotAvailability]
}

struct TimeSlotAvailability {
    let timeSlot: String
    let isAvailable: Bool
}

// MARK: - RoomFinder Repository
class RoomFinderRepository: ObservableObject {
    private let keychainManager = KeychainManager.shared

    @Published var availableRooms: [RoomAvailability] = []

    func findAvailableRooms(for user: User, date: Date, timeSlot: TimeSlot) async throws {
        // This is a mock implementation - in reality, you'd call the Untis API
        // The actual API endpoint for room finding is not documented in the Android code
        // so this provides a placeholder structure

        // Generate mock data for demonstration
        let mockRooms: [Room] = [
            Room(id: 1, name: "A101", longName: "Classroom A101", active: true, building: "Building A"),
            Room(id: 2, name: "A102", longName: "Classroom A102", active: true, building: "Building A"),
            Room(id: 3, name: "B201", longName: "Lab B201", active: true, building: "Building B"),
            Room(id: 4, name: "B202", longName: "Computer Lab B202", active: true, building: "Building B"),
            Room(id: 5, name: "Gym1", longName: "Gymnasium 1", active: true, building: "Sports Hall"),
            Room(id: 6, name: "Lib", longName: "Library", active: true, building: "Main Building")
        ]

        let roomAvailabilities = mockRooms.map { room in
            RoomAvailability(
                room: room,
                isAvailable: Bool.random(),
                timeline: generateMockTimeline()
            )
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            self.availableRooms = roomAvailabilities.sorted { $0.isAvailable && !$1.isAvailable }
        }
    }

    private func generateMockTimeline() -> [TimeSlotAvailability] {
        return [
            TimeSlotAvailability(timeSlot: "08:00", isAvailable: Bool.random()),
            TimeSlotAvailability(timeSlot: "09:45", isAvailable: Bool.random()),
            TimeSlotAvailability(timeSlot: "11:30", isAvailable: Bool.random()),
            TimeSlotAvailability(timeSlot: "14:00", isAvailable: Bool.random()),
            TimeSlotAvailability(timeSlot: "15:45", isAvailable: Bool.random()),
            TimeSlotAvailability(timeSlot: "17:30", isAvailable: Bool.random())
        ]
    }
}

#Preview {
    RoomFinderView()
        .environmentObject(UserRepository())
}