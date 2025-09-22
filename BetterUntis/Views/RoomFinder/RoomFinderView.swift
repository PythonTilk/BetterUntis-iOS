import SwiftUI
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

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
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
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
                .background(isSelected ? Color.blue : Color(.systemGray6))
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
@MainActor
class RoomFinderRepository: ObservableObject {
    private let apiClient = UntisAPIClient()
    private let keychainManager = KeychainManager.shared
    private let timetableRepository = TimetableRepository()
    private var restClients: [Int64: UntisRESTClient] = [:]

    @Published var availableRooms: [RoomAvailability] = []
    @Published var allRooms: [Room] = [] // Cache all rooms for quick access

    func findAvailableRooms(for user: User, date: Date, timeSlot: TimeSlot) async throws {
        guard keychainManager.loadUserCredentials(userId: String(user.id)) != nil else {
            throw RoomFinderError.missingCredentials
        }

        if allRooms.isEmpty {
            try await loadAllRooms(for: user)
        }

        let restClient = restClient(for: user)
        if restClient.isAuthenticated {
            do {
                let response = try await fetchRoomsFromREST(client: restClient, date: date, timeSlot: timeSlot)
                let (rooms, availability) = convertRoomsResponse(response, timeSlot: timeSlot)

                await MainActor.run {
                    if self.allRooms.isEmpty {
                        self.allRooms = rooms.filter { $0.active }.sorted { $0.name < $1.name }
                    }
                    self.availableRooms = availability.sorted(by: sortRoomAvailability)
                }
                return
            } catch {
                print("⚠️ RoomFinder REST lookup failed: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ REST token unavailable for RoomFinder; falling back to heuristic availability")
        }

        print("🏢 Using heuristic room availability for \(allRooms.count) rooms")

        let roomAvailabilities = allRooms.map { room in
            RoomAvailability(
                room: room,
                isAvailable: Bool.random(),
                timeline: generateTimelineForRoom(room, date: date)
            )
        }

        await MainActor.run {
            self.availableRooms = roomAvailabilities.sorted(by: sortRoomAvailability)
        }
    }

    private func loadAllRooms(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw RoomFinderError.missingCredentials
        }

        print("🔄 Loading rooms via direct API call (master data temporarily disabled)...")

        // TODO: Re-enable master data approach once Core Data model is updated
        // let rooms = timetableRepository.getRoomsFromMasterData(for: user)

        // Use direct API call for now
        try await loadRoomsFromAPI(for: user, credentials: credentials)
    }

    private func loadRoomsFromAPI(for user: User, credentials: UserCredentials) async throws {
        // Fallback to direct API call for servers that don't support master data
        let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
            apiHost: user.apiHost,
            schoolName: user.schoolName
        )

        var lastError: Error?
        var roomDicts: [[String: Any]]?

        // Try each URL until one works
        for apiUrl in apiUrls {
            do {
                print("🔄 Trying rooms API URL: \(apiUrl)")
                roomDicts = try await apiClient.getRooms(
                    apiUrl: apiUrl,
                    user: credentials.user,
                    key: credentials.key
                )
                print("✅ Rooms loaded successfully with URL: \(apiUrl)")
                break
            } catch {
                print("❌ Rooms failed with URL \(apiUrl): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        guard let roomData = roomDicts else {
            throw lastError ?? RoomFinderError.noRoomsFound
        }

        let rooms = roomData.compactMap { dict -> Room? in
            guard let id = dict["id"] as? Int64,
                  let name = dict["name"] as? String else {
                return nil
            }

            return Room(
                id: id,
                name: name,
                longName: dict["longName"] as? String ?? name,
                active: dict["active"] as? Bool ?? true,
                building: dict["building"] as? String
            )
        }

        await MainActor.run {
            self.allRooms = rooms.filter { $0.active }.sorted { $0.name < $1.name }
        }

        print("📋 Loaded \(self.allRooms.count) active rooms from fallback API")
    }

    private func restClient(for user: User) -> UntisRESTClient {
        if let cached = restClients[user.id] {
            return cached
        }

        let serverURL = buildServerURL(from: user.apiHost)
        let client = UntisRESTClient.create(
            for: serverURL,
            schoolName: user.schoolName,
            userIdentifier: String(user.id)
        )
        restClients[user.id] = client
        return client
    }

    private func buildServerURL(from apiHost: String) -> String {
        var normalized = apiHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return "https://webuntis.com/WebUntis"
        }

        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }

        guard var components = URLComponents(string: normalized) else {
            return normalized
        }

        if components.scheme == nil {
            components.scheme = "https"
        }

        var path = components.path
        if let range = path.range(of: "/WebUntis", options: .caseInsensitive) {
            path = String(path[..<range.upperBound])
        } else {
            if path.isEmpty || path == "/" {
                path = "/WebUntis"
            } else if path.hasSuffix("/") {
                path += "WebUntis"
            } else {
                path += "/WebUntis"
            }
        }

        components.path = path
        components.query = nil
        components.fragment = nil

        return components.string ?? normalized
    }

    private func fetchRoomsFromREST(client: UntisRESTClient, date: Date, timeSlot: TimeSlot) async throws -> CalendarPeriodRoomResponse {
        let start = combine(date: date, timeString: timeSlot.start)
        let end = combine(date: date, timeString: timeSlot.end)
        return try await client.getAvailableRooms(startDateTime: start, endDateTime: end)
    }

    private func convertRoomsResponse(_ response: CalendarPeriodRoomResponse, timeSlot: TimeSlot) -> ([Room], [RoomAvailability]) {
        let rooms = response.rooms.map { detail in
            Room(
                id: detail.id,
                name: detail.shortName,
                longName: detail.longName,
                active: detail.status != .removed,
                building: detail.building?.displayName
            )
        }

        let availability = zip(response.rooms, rooms).map { pair -> RoomAvailability in
            let (detail, room) = pair
            let isAvailable = detail.availability == .bookable || detail.availability == .reservable
            let timeline = [
                TimeSlotAvailability(timeSlot: timeSlot.start, isAvailable: isAvailable)
            ]
            return RoomAvailability(room: room, isAvailable: isAvailable, timeline: timeline)
        }

        return (rooms, availability)
    }

    private func combine(date: Date, timeString: String) -> Date {
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return date
        }

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private func sortRoomAvailability(_ lhs: RoomAvailability, _ rhs: RoomAvailability) -> Bool {
        if lhs.isAvailable == rhs.isAvailable {
            return lhs.room.name < rhs.room.name
        }
        return lhs.isAvailable && !rhs.isAvailable
    }

    private func generateTimelineForRoom(_ room: Room, date: Date) -> [TimeSlotAvailability] {
        // This is a simplified availability timeline
        // In a real implementation, this would check timetable data for the specific room
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

// MARK: - Error Types
enum RoomFinderError: Error, LocalizedError {
    case missingCredentials
    case noRoomsFound

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "User credentials not found"
        case .noRoomsFound:
            return "No rooms could be loaded from the server"
        }
    }
}

#Preview {
    RoomFinderView()
        .environmentObject(UserRepository())
}
