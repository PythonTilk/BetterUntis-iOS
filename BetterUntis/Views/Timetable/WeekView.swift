import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct WeekView: View {
    let timetable: Timetable
    let currentWeekStartDate: Date
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedPeriod: Period?

    private let dayWidth: CGFloat = 120
    private let hourHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 50
    private let headerHeight: CGFloat = 50

    // Time range constants (6 AM to 10 PM)
    private let startHour: Int = 6
    private let endHour: Int = 22
    private let totalHours: Int = 16

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with day labels
                WeekHeaderView(
                    currentWeekStartDate: currentWeekStartDate,
                    dayWidth: dayWidth,
                    timeColumnWidth: timeColumnWidth
                )
                .frame(height: headerHeight)

                // Scrollable timetable content
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Time column
                        TimeColumnView(
                            startHour: startHour,
                            endHour: endHour,
                            hourHeight: hourHeight
                        )
                        .frame(width: timeColumnWidth)

                        // Days columns
                        HStack(alignment: .top, spacing: 1) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                DayColumnView(
                                    date: Calendar.current.date(byAdding: .day, value: dayIndex, to: currentWeekStartDate)!,
                                    periods: getPeriodsForDay(dayIndex),
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    startHour: startHour,
                                    onPeriodTap: { period in
                                        selectedPeriod = period
                                    }
                                )
                                .frame(width: dayWidth)
                            }
                        }
                    }
                    .frame(
                        width: timeColumnWidth + (dayWidth * 7) + 6, // +6 for spacing
                        height: CGFloat(totalHours) * hourHeight
                    )
                }
                .coordinateSpace(name: "weekView")
            }
        }
        .sheet(item: Binding<Period?>(
            get: { selectedPeriod },
            set: { selectedPeriod = $0 }
        )) { period in
            PeriodDetailView(period: period)
        }
    }

    private func getPeriodsForDay(_ dayIndex: Int) -> [Period] {
        guard let dayDate = Calendar.current.date(byAdding: .day, value: dayIndex, to: currentWeekStartDate) else {
            return []
        }

        return timetable.periods.filter { period in
            Calendar.current.isDate(period.startDateTime, inSameDayAs: dayDate)
        }
    }
}

// MARK: - Week Header View
struct WeekHeaderView: View {
    let currentWeekStartDate: Date
    let dayWidth: CGFloat
    let timeColumnWidth: CGFloat

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Empty space for time column
            Rectangle()
                .fill(Color.clear)
                .frame(width: timeColumnWidth)

            // Day headers
            HStack(spacing: 1) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    VStack(spacing: 2) {
                        Text(dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: dayIndex, to: currentWeekStartDate)!))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: dayIndex, to: currentWeekStartDate)!))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(width: dayWidth)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
        .background(Color(UIColor.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Time Column View
struct TimeColumnView: View {
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                VStack(alignment: .leading) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    Spacer()
                }
                .frame(height: hourHeight)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(.gray.opacity(0.2)),
                    alignment: .bottom
                )
            }
        }
        .background(Color(UIColor.systemGray6))
    }
}

// MARK: - Day Column View
struct DayColumnView: View {
    let date: Date
    let periods: [Period]
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let startHour: Int
    let onPeriodTap: (Period) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background with hour lines
            VStack(spacing: 0) {
                ForEach(startHour..<(startHour + 16), id: \.self) { _ in
                    Rectangle()
                        .frame(height: hourHeight)
                        .foregroundColor(.clear)
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.gray.opacity(0.2)),
                            alignment: .bottom
                        )
                }
            }

            // Periods
            ForEach(periods, id: \.id) { period in
                PeriodView(
                    period: period,
                    dayWidth: dayWidth,
                    hourHeight: hourHeight,
                    startHour: startHour,
                    onTap: { onPeriodTap(period) }
                )
            }
        }
        .frame(width: dayWidth)
    }
}

// MARK: - Period View
struct PeriodView: View {
    let period: Period
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let startHour: Int
    let onTap: () -> Void

    private var yPosition: CGFloat {
        let calendar = Calendar.current
        let periodStartHour = calendar.component(.hour, from: period.startDateTime)
        let periodStartMinute = calendar.component(.minute, from: period.startDateTime)

        let hoursFromStart = max(0, periodStartHour - startHour)
        let minuteOffset = CGFloat(periodStartMinute) / 60.0

        return CGFloat(hoursFromStart) * hourHeight + (minuteOffset * hourHeight)
    }

    private var periodHeight: CGFloat {
        let duration = period.endDateTime.timeIntervalSince(period.startDateTime) / 3600.0 // hours
        return CGFloat(duration) * hourHeight
    }

    private var backgroundColor: Color {
        Color(hex: period.backColor) ?? .blue.opacity(0.3)
    }

    private var foregroundColor: Color {
        Color(hex: period.foreColor) ?? .primary
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                if let lessonText = period.text.lesson {
                    Text(lessonText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if !period.elements.isEmpty {
                    Text(period.elements.map(\.name).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Time display
                HStack {
                    Text(timeString(from: period.startDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(timeString(from: period.endDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(width: dayWidth - 2, height: max(30, periodHeight - 1))
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(foregroundColor.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .offset(x: 1, y: yPosition)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Period Detail View
struct PeriodDetailView: View {
    let period: Period

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Period title
                    if let lessonText = period.text.lesson {
                        Text(lessonText)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    // Time information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time")
                            .font(.headline)

                        HStack {
                            Text("Start:")
                            Spacer()
                            Text(DateFormatter.timeAndDate.string(from: period.startDateTime))
                        }

                        HStack {
                            Text("End:")
                            Spacer()
                            Text(DateFormatter.timeAndDate.string(from: period.endDateTime))
                        }
                    }

                    // Elements (teachers, rooms, etc.)
                    if !period.elements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)

                            ForEach(period.elements, id: \.id) { element in
                                HStack {
                                    Text(getElementTypeString(element.type) + ":")
                                    Spacer()
                                    Text(element.longName.isEmpty ? element.name : element.longName)
                                }
                            }
                        }
                    }

                    // Additional info
                    if let info = period.text.info, !info.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Information")
                                .font(.headline)
                            Text(info)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Period Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by sheet binding
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let timeAndDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private func getElementTypeString(_ elementType: ElementType) -> String {
    switch elementType {
    case .klasse:
        return "Class"
    case .teacher:
        return "Teacher"
    case .subject:
        return "Subject"
    case .room:
        return "Room"
    case .student:
        return "Student"
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


#Preview {
    let samplePeriods = [
        Period(
            id: 1,
            lessonId: 1,
            startDateTime: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 8, minute: 0))!,
            endDateTime: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 9, minute: 30))!,
            foreColor: "#000000",
            backColor: "#FF6B6B",
            innerForeColor: "#000000",
            innerBackColor: "#FF6B6B",
            text: PeriodText(lesson: "Mathematics", substitution: nil, info: "Room changed"),
            elements: [
                PeriodElement(type: .teacher, id: 1, name: "Smith", longName: "John Smith", displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil),
                PeriodElement(type: .room, id: 101, name: "A101", longName: "Room A101", displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil)
            ],
            can: [],
            is: [],
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: false,
            messengerChannel: nil,
            onlinePeriodLink: nil,
            blockHash: nil
        )
    ]

    let sampleTimetable = Timetable(
        displayableStartDate: Calendar.current.startOfDay(for: Date()),
        displayableEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
        periods: samplePeriods
    )

    WeekView(
        timetable: sampleTimetable,
        currentWeekStartDate: Calendar.current.startOfDay(for: Date())
    )
}