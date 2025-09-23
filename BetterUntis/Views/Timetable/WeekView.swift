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

    private var effectiveBackgroundColor: Color {
        period.isCancelledLesson ? Color(UIColor.systemGray5) : backgroundColor
    }

    private var effectiveForegroundColor: Color {
        period.isCancelledLesson ? .secondary : foregroundColor
    }

    private var isCancelledLesson: Bool {
        period.isCancelledLesson
    }

    private var hasTeacherSubstitution: Bool {
        period.`is`(.teacherSubstitution)
    }

    private var hasRoomChange: Bool {
        period.`is`(.roomSubstitution)
    }

    private var isExamPeriod: Bool {
        period.`is`(.exam) || period.exam != nil
    }

    private var statusBadges: [(text: String, color: Color)] {
        var badges: [(text: String, color: Color)] = []

        if isCancelledLesson {
            badges.append(("Cancelled", Color(UIColor.systemRed)))
        }

        if let examLabel = period.examStatusLabel {
            badges.append((examLabel, Color(UIColor.systemOrange)))
        }

        return badges
    }

    private var examDetailText: String? { period.examDetailText }

    private var supplementalInfoText: String? {
        guard let info = period.infoSummary else { return nil }

        if let examDetailText, info == examDetailText {
            return nil
        }

        return info
    }

    private var outlineConfigurations: [(color: Color, inset: CGFloat)] {
        var configs: [(Color, CGFloat)] = []

        if isExamPeriod {
            configs.append((Color(UIColor.systemYellow), 0))
        }

        if hasRoomChange {
            let inset = configs.isEmpty ? 0 : 3
            configs.append((Color(UIColor.systemPurple), inset))
        }

        if hasTeacherSubstitution {
            let inset = configs.isEmpty ? 0 : (configs.last?.inset ?? 0) + 3
            configs.append((Color(UIColor.systemGreen), inset))
        }

        return configs
    }

    @ViewBuilder
    private var outlineOverlay: some View {
        if outlineConfigurations.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .stroke(effectiveForegroundColor.opacity(0.2), lineWidth: 0.5)
        } else {
            ZStack {
                ForEach(Array(outlineConfigurations.enumerated()), id: \.offset) { _, configuration in
                    RoundedRectangle(cornerRadius: 8)
                        .inset(by: configuration.inset)
                        .stroke(configuration.color, lineWidth: 2)
                }
            }
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.displayLessonTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(isCancelledLesson, color: .secondary)

                    if !statusBadges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(statusBadges.enumerated()), id: \.offset) { _, badge in
                                StatusBadge(text: badge.text, color: badge.color)
                            }
                        }
                    }
                }

                if let classes = period.classSummary {
                    InfoRow(
                        icon: "person.3.fill",
                        text: classes,
                        textColor: effectiveForegroundColor,
                        lineLimit: 2,
                        strikethrough: isCancelledLesson
                    )
                }

                if let teacher = period.teacherSummary {
                    InfoRow(
                        icon: "person.fill",
                        text: teacher,
                        textColor: effectiveForegroundColor,
                        lineLimit: 2,
                        strikethrough: isCancelledLesson
                    )
                }

                if let substitution = period.substitutionSummary {
                    InfoRow(
                        icon: "person.crop.circle.badge.exclam",
                        text: substitution,
                        textColor: Color(UIColor.systemGreen),
                        lineLimit: 3,
                        strikethrough: isCancelledLesson
                    )
                }

                if let room = period.roomSummary {
                    InfoRow(
                        icon: "mappin.and.ellipse",
                        text: room,
                        textColor: effectiveForegroundColor,
                        lineLimit: 2,
                        strikethrough: isCancelledLesson
                    )
                }

                if let examDetailText {
                    InfoRow(
                        icon: "doc.text",
                        text: examDetailText,
                        textColor: Color(UIColor.systemOrange),
                        lineLimit: 3,
                        strikethrough: isCancelledLesson
                    )
                }

                if let homework = period.homeworkSummary {
                    InfoRow(
                        icon: "checklist",
                        text: homework,
                        textColor: effectiveForegroundColor,
                        lineLimit: 3,
                        strikethrough: isCancelledLesson
                    )
                }

                if let info = supplementalInfoText {
                    InfoRow(
                        icon: "info.circle",
                        text: info,
                        textColor: effectiveForegroundColor,
                        lineLimit: 3,
                        strikethrough: isCancelledLesson
                    )
                }

                Spacer(minLength: 0)

                HStack {
                    Text(timeString(from: period.startDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .strikethrough(isCancelledLesson, color: .secondary)

                    Spacer()

                    Text(timeString(from: period.endDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .strikethrough(isCancelledLesson, color: .secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(width: dayWidth - 2, height: max(44, periodHeight - 1))
            .background(effectiveBackgroundColor)
            .foregroundColor(effectiveForegroundColor)
            .cornerRadius(8)
            .overlay(outlineOverlay)
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
                VStack(alignment: .leading, spacing: 20) {
                    Text(period.displayLessonTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    if period.isCancelledLesson || period.examStatusLabel != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            if period.isCancelledLesson {
                                StatusBadge(text: "Cancelled", color: .red)
                            }

                            if let examText = period.examStatusLabel {
                                StatusBadge(text: examText, color: .orange)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time")
                            .font(.headline)

                        InfoRow(
                            icon: "clock.fill",
                            text: "Start: \(DateFormatter.timeAndDate.string(from: period.startDateTime))",
                            font: .subheadline,
                            lineLimit: 1
                        )

                        InfoRow(
                            icon: "clock",
                            text: "End: \(DateFormatter.timeAndDate.string(from: period.endDateTime))",
                            font: .subheadline,
                            lineLimit: 1
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)

                        if let subject = period.subjectSummary {
                            InfoRow(icon: "book.fill", text: subject, font: .subheadline, lineLimit: 3)
                        }

                        if let classes = period.classSummary {
                            InfoRow(icon: "person.3.fill", text: classes, font: .subheadline, lineLimit: 3)
                        }

                        if let teacher = period.teacherSummary {
                            InfoRow(icon: "person.fill", text: teacher, font: .subheadline, lineLimit: 3)
                        }

                        if let room = period.roomSummary {
                            InfoRow(icon: "mappin.and.ellipse", text: room, font: .subheadline, lineLimit: 3)
                        }

                        if let substitution = period.substitutionSummary {
                            InfoRow(icon: "person.crop.circle.badge.exclam", text: substitution, font: .subheadline, lineLimit: 3)
                        }

                        if let examDetail = period.examDetailText {
                            InfoRow(
                                icon: "doc.text",
                                text: examDetail,
                                font: .subheadline,
                                textColor: Color(UIColor.systemOrange),
                                lineLimit: 3
                            )
                        }
                    }

                    if let homeworks = period.homeWorks, !homeworks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Homework")
                                .font(.headline)

                            ForEach(homeworks, id: \.id) { homework in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(homework.text.isEmpty ? "Homework" : homework.text)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    InfoRow(
                                        icon: "calendar",
                                        text: "Due: \(dueDateString(for: homework.dueDate))",
                                        font: .caption,
                                        lineLimit: 1
                                    )

                                    HStack(spacing: 8) {
                                        StatusBadge(text: homework.completed ? "Completed" : "Pending", color: homework.completed ? .green : .blue)

                                        if let remark = homework.remark, !remark.isEmpty {
                                            Text(remark)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }

                    if let info = period.infoSummary, info != period.examDetailText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Information")
                                .font(.headline)
                            Text(info)
                        }
                    }
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

    private func dueDateString(for date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
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

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String
    var font: Font = .caption2
    var textColor: Color = .primary
    var lineLimit: Int = 2
    var strikethrough: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .font(font)
                .foregroundColor(.secondary)

            Text(text)
                .font(font)
                .foregroundColor(textColor)
                .strikethrough(strikethrough, color: textColor)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
    }
}

private extension Period {
    var displayLessonTitle: String {
        if let lesson = text.lesson?.trimmingCharacters(in: .whitespacesAndNewlines), !lesson.isEmpty {
            return lesson
        }

        if let subject = elements.first(where: { $0.type == .subject }) {
            return subject.displayText
        }

        return "Lesson"
    }

    var teacherSummary: String? { summary(for: .teacher) }

    var roomSummary: String? { summary(for: .room) }

    var classSummary: String? { summary(for: .klasse) }

    var subjectSummary: String? { summary(for: .subject) }

    var isCancelledLesson: Bool {
        self.`is`(.cancelled)
    }

    var examSummary: String? {
        guard let exam = exam else { return nil }

        let components = [exam.name, exam.text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !components.isEmpty {
            return components.joined(separator: " – ")
        }

        if let type = exam.examType?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty {
            return type.capitalized
        }

        return "Class Test"
    }

    var examStatusLabel: String? {
        guard `is`(.exam) || exam != nil else { return nil }

        if let summary = examSummary {
            return summary.count > 18 ? "Exam" : summary
        }

        return "Exam"
    }

    var examDetailText: String? {
        if let summary = examSummary {
            return summary
        }

        if `is`(.exam) {
            return infoSummary ?? "Exam"
        }

        return nil
    }

    var infoSummary: String? {
        guard let info = text.info?.trimmingCharacters(in: .whitespacesAndNewlines), !info.isEmpty else {
            return nil
        }

        return info
    }

    var homeworkSummary: String? {
        guard let homeworks = homeWorks, !homeworks.isEmpty else { return nil }

        if let first = homeworks.first(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return first.text
        }

        return homeworks.count == 1 ? "Homework assigned" : "Homework: \(homeworks.count) tasks"
    }

    var substitutionSummary: String? {
        if let substitution = text.substitution?.trimmingCharacters(in: .whitespacesAndNewlines), !substitution.isEmpty {
            return substitution
        }

        if self.`is`(.teacherSubstitution) {
            return "Substitute teacher"
        }

        if self.`is`(.roomSubstitution) {
            return "Room substitution"
        }

        if self.`is`(.subjectSubstitution) {
            return "Subject substitution"
        }

        return nil
    }

    private func summary(for type: ElementType) -> String? {
        let names = elements
            .filter { $0.type == type }
            .map { $0.displayText }
            .filter { !$0.isEmpty }

        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

private extension PeriodElement {
    var displayText: String {
        if let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }

        if !longName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return longName
        }

        return name
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