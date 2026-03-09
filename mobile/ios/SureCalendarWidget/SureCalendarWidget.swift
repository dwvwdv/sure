import WidgetKit
import SwiftUI

// MARK: - Data Models

struct CalendarEntry: TimelineEntry {
    let date: Date
    let year: Int
    let month: Int
    let accountName: String
    let currency: String
    let monthlyTotal: Double
    let dailyTotals: [String: Double]
    let lastUpdated: String
}

// MARK: - Timeline Provider

struct CalendarProvider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.am.sure.mobile.widget")

    func placeholder(in context: Context) -> CalendarEntry {
        let now = Date()
        let calendar = Calendar.current
        return CalendarEntry(
            date: now,
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now),
            accountName: "All Accounts",
            currency: "$",
            monthlyTotal: 0.0,
            dailyTotals: [:],
            lastUpdated: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let entry = readEntry()
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readEntry() -> CalendarEntry {
        let now = Date()
        let calendar = Calendar.current

        let year = userDefaults?.integer(forKey: "widget_year") ?? calendar.component(.year, from: now)
        let month = userDefaults?.integer(forKey: "widget_month") ?? calendar.component(.month, from: now)
        let accountName = userDefaults?.string(forKey: "widget_account_name") ?? "All Accounts"
        let currency = userDefaults?.string(forKey: "widget_currency") ?? ""
        let monthlyTotalStr = userDefaults?.string(forKey: "widget_monthly_total") ?? "0.00"
        let dailyTotalsJson = userDefaults?.string(forKey: "widget_daily_totals") ?? "{}"
        let lastUpdated = userDefaults?.string(forKey: "widget_last_updated") ?? ""

        let monthlyTotal = Double(monthlyTotalStr) ?? 0.0

        var dailyTotals: [String: Double] = [:]
        if let data = dailyTotalsJson.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in json {
                if let doubleValue = value as? Double {
                    dailyTotals[key] = doubleValue
                } else if let numValue = value as? NSNumber {
                    dailyTotals[key] = numValue.doubleValue
                }
            }
        }

        return CalendarEntry(
            date: now,
            year: year == 0 ? calendar.component(.year, from: now) : year,
            month: month == 0 ? calendar.component(.month, from: now) : month,
            accountName: accountName,
            currency: currency,
            monthlyTotal: monthlyTotal,
            dailyTotals: dailyTotals,
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - Widget Views

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    @Environment(\.widgetFamily) var family

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("Sure Calendar")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text(monthYearText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Account and total
            HStack {
                Text(entry.accountName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(formattedTotal)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(entry.monthlyTotal >= 0 ? .green : .red)
            }

            Divider()

            // Weekday headers
            HStack(spacing: 2) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let gridData = calendarGrid()
            ForEach(0..<gridData.count, id: \.self) { week in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { day in
                        let cellData = gridData[week][day]
                        DayCellView(cellData: cellData, currency: entry.currency)
                    }
                }
            }

            Spacer(minLength: 0)

            // Last updated
            if !entry.lastUpdated.isEmpty {
                HStack {
                    Spacer()
                    Text(formattedLastUpdated)
                        .font(.system(size: 8))
                        .foregroundColor(Color.gray.opacity(0.6))
                }
            }
        }
        .padding(12)
    }

    private var monthYearText: String {
        let monthIndex = entry.month - 1
        let name = (monthIndex >= 0 && monthIndex < 12) ? monthNames[monthIndex] : ""
        return "\(name) \(entry.year)"
    }

    private var formattedTotal: String {
        let sign = entry.monthlyTotal >= 0 ? "+" : ""
        return "\(sign)\(entry.currency)\(String(format: "%.2f", abs(entry.monthlyTotal)))"
    }

    private var formattedLastUpdated: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: entry.lastUpdated) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return "Updated \(displayFormatter.string(from: date))"
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: entry.lastUpdated) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return "Updated \(displayFormatter.string(from: date))"
        }

        return ""
    }

    private func calendarGrid() -> [[DayCellData]] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday

        var components = DateComponents()
        components.year = entry.year
        components.month = entry.month
        components.day = 1
        guard let firstDay = calendar.date(from: components) else { return [] }

        let firstWeekday = (calendar.component(.weekday, from: firstDay) - 1) // 0 = Sunday
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        let today = Date()
        let todayYear = calendar.component(.year, from: today)
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)

        let totalCells = firstWeekday + daysInMonth
        let totalRows = (totalCells + 6) / 7

        var grid: [[DayCellData]] = []

        for week in 0..<totalRows {
            var row: [DayCellData] = []
            for day in 0..<7 {
                let position = week * 7 + day
                let dayNum = position - firstWeekday + 1

                if dayNum < 1 || dayNum > daysInMonth {
                    row.append(DayCellData(dayNumber: nil, total: nil, isToday: false))
                } else {
                    let dateKey = String(format: "%04d-%02d-%02d", entry.year, entry.month, dayNum)
                    let total = entry.dailyTotals[dateKey]
                    let isToday = entry.year == todayYear && entry.month == todayMonth && dayNum == todayDay

                    row.append(DayCellData(dayNumber: dayNum, total: total, isToday: isToday))
                }
            }
            grid.append(row)
        }

        return grid
    }
}

struct DayCellData {
    let dayNumber: Int?
    let total: Double?
    let isToday: Bool
}

struct DayCellView: View {
    let cellData: DayCellData
    let currency: String

    var body: some View {
        if let dayNumber = cellData.dayNumber {
            VStack(spacing: 0) {
                Text("\(dayNumber)")
                    .font(.system(size: 10, weight: cellData.isToday ? .bold : .medium))

                if let total = cellData.total, total != 0 {
                    Text(formatCompact(total))
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(total > 0 ? .green : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(cellData.isToday ? Color(red: 0.39, green: 0.4, blue: 0.95) : Color.clear, lineWidth: 1)
            )
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backgroundColor: Color {
        if cellData.isToday {
            return Color(red: 0.93, green: 0.95, blue: 1.0)
        }
        if let total = cellData.total {
            if total > 0 {
                return Color.green.opacity(0.12)
            } else if total < 0 {
                return Color.red.opacity(0.12)
            }
        }
        return Color.clear
    }

    private func formatCompact(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let sign = value > 0 ? "+" : ""
        if abs >= 1_000_000 {
            return "\(sign)\(String(format: "%.1fM", value / 1_000_000))"
        } else if abs >= 1000 {
            return "\(sign)\(String(format: "%.1fK", value / 1000))"
        } else if abs >= 100 {
            return "\(sign)\(String(format: "%.0f", value))"
        } else {
            return "\(sign)\(String(format: "%.1f", value))"
        }
    }
}

// MARK: - Widget Configuration

@main
struct SureCalendarWidget: Widget {
    let kind: String = "SureCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                CalendarWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                CalendarWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Sure Calendar")
        .description("Monthly calendar showing daily transaction totals")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
