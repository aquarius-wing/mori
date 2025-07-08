import SwiftUI

struct CustomContributionGridView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let activities: [GameActivityData]
    
    private var dateHoursMap: [Date: Double] {
        var calendar = Calendar.current
        // time zone is UTC
        calendar.timeZone = TimeZone.current
        var map: [Date: Double] = [:]
        for activity in activities {
            let dayStart = calendar.startOfDay(for: activity.date)
            map[dayStart, default: 0] += activity.hours
        }
        return map
    }
    
    private var contributionColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.12, green: 0.16, blue: 0.20), // Empty/0 hours - darker background
                Color(red: 0.0, green: 0.45, blue: 0.25),  // Low (< 1 hour)
                Color(red: 0.0, green: 0.6, blue: 0.35),   // Medium (1-3 hours)
                Color(red: 0.15, green: 0.75, blue: 0.45), // High (3-5 hours)
                Color(red: 0.3, green: 0.9, blue: 0.55)    // Very High (5+ hours)
            ]
        } else {
            return [
                Color(red: 0.92, green: 0.92, blue: 0.92), // Empty/0 hours
                Color(red: 0.76, green: 0.91, blue: 0.83),  // Low (< 1 hour)
                Color(red: 0.51, green: 0.83, blue: 0.66),  // Medium (1-3 hours)
                Color(red: 0.23, green: 0.66, blue: 0.40),  // High (3-5 hours)
                Color(red: 0.11, green: 0.53, blue: 0.23)   // Very High (5+ hours)
            ]
        }
    }
    
        var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width // Account for padding
            let weekdayLabelWidth: CGFloat = 15
            let squareSize: CGFloat = 11
            let spacing: CGFloat = 3
            let gridWidth = availableWidth - weekdayLabelWidth - spacing
            let maxColumns = Int((gridWidth + spacing) / (squareSize + spacing))
            let actualColumns = min(maxColumns, 53) // Don't exceed 53 weeks
            let monthSpan: Int = 4 // Each month label spans 4 columns
            
            VStack(alignment: .leading, spacing: 8) {
                // Month labels using grid layout
                monthHeaderGridView(columns: actualColumns, squareSize: squareSize, spacing: spacing, monthSpan: monthSpan)
                
                // Main grid with weekday labels
                HStack(alignment: .top, spacing: spacing) {
                    weekdayLabelsView(squareSize: squareSize, spacing: spacing)
                    contributionGridView(columns: actualColumns, squareSize: squareSize, spacing: spacing)
                }
                
                // Legend
                legendView(squareSize: squareSize)
            }
            // .padding()
            // .background(
            //     RoundedRectangle(cornerRadius: 12)
            //         .fill(colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color.white)
            //         .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            // )
        }
        .frame(height: 150) // Fixed height for the contribution grid
    }

    // MARK: - Subviews
    
    private func monthHeaderGridView(columns: Int, squareSize: CGFloat, spacing: CGFloat, monthSpan: Int) -> some View {
        let calendar = Calendar.current
        let startDate = getStartDate(actualColumns: columns)
        let monthSymbols = calendar.shortMonthSymbols
        let spanWidth = CGFloat(monthSpan) * squareSize + CGFloat(monthSpan - 1) * spacing
        
        return HStack(spacing: 0) {
            Spacer().frame(width: 24) // Space for weekday labels
            
            HStack(spacing: spacing) {
                // Create month headers with 4-column spans
                ForEach(Array(stride(from: 0, to: columns, by: monthSpan)), id: \.self) { startColumn in
                    if startColumn < columns {
                        let weekDate = calendar.date(byAdding: .weekOfYear, value: startColumn, to: startDate)!
                        let monthOfWeek = calendar.component(.month, from: weekDate)
                        
                        Text(monthSymbols[monthOfWeek - 1])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: spanWidth, alignment: .leading)
                    }
                }
                
                // Fill remaining space if needed
                let remainingColumns = columns % monthSpan
                if remainingColumns > 0 {
                    let remainingWidth = CGFloat(remainingColumns) * squareSize + CGFloat(max(0, remainingColumns - 1)) * spacing
                    Spacer()
                        .frame(width: remainingWidth)
                }
            }
        }
    }
    
    private func weekdayLabelsView(squareSize: CGFloat, spacing: CGFloat) -> some View {
        let weekdays = ["", "Mon", "", "Wed", "", "Fri", ""]
        
        return VStack(spacing: spacing) {
            ForEach(weekdays.indices, id: \.self) { index in
                Text(weekdays[index])
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
            }
        }
    }
    
    private func contributionGridView(columns: Int, squareSize: CGFloat, spacing: CGFloat) -> some View {
        let startDate = getStartDate(actualColumns: columns)
        
        return HStack(spacing: spacing) {
            ForEach(0..<columns, id: \.self) { week in
                weekColumnView(week: week, startDate: startDate, squareSize: squareSize, spacing: spacing)
            }
        }
    }

    private func weekColumnView(week: Int, startDate: Date, squareSize: CGFloat, spacing: CGFloat) -> some View {
        let calendar = Calendar.current
        
        return VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { day in
                let date = calendar.date(byAdding: .day, value: (week * 7) + day, to: startDate)!
                let hours = dateHoursMap[date] ?? 0
                let level = getContributionLevel(hours: hours)
                
                Rectangle()
                    .fill(contributionColors[level])
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(2)
                    .opacity(date > Date() ? 0.3 : 1.0)
            }
        }
    }
    
    private func legendView(squareSize: CGFloat) -> some View {
        return HStack(spacing: 8) {
            Spacer()
            
            Text("Less")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { level in
                    Rectangle()
                        .fill(contributionColors[level])
                        .frame(width: squareSize, height: squareSize)
                        .cornerRadius(2)
                }
            }
            
            Text("More")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getStartDate(actualColumns: Int) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Set Sunday as the first day of the week
        calendar.timeZone = TimeZone.current // Use current time zone
        
        let today = Date()
        
        // Find the Sunday of the current week
        let todayWeekday = calendar.component(.weekday, from: today)
        let daysFromSunday = todayWeekday - 1 // Sunday is 1, so days to subtract
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else { return today }
        let currentWeekSundayStart = calendar.startOfDay(for: currentWeekSunday)
        
        // Go back (actualColumns - 1) weeks from current week's Sunday
        let weeksToGoBack = actualColumns - 1
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeksToGoBack, to: currentWeekSundayStart) else { return currentWeekSundayStart }
        
        return calendar.startOfDay(for: startDate)
    }
    
    private func getContributionLevel(hours: Double) -> Int {
        switch hours {
        case 0: return 0
        case 0..<1: return 1
        case 1..<3: return 2
        case 3..<5: return 3
        default: return 4
        }
    }
}

#if DEBUG
struct CustomContributionGridView_Previews: PreviewProvider {
    static func generatePreviewData() -> [GameActivityData] {
        var data: [GameActivityData] = []
        let calendar = Calendar.current
        for i in 0..<365 {
            if Bool.random() {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let hours = Double.random(in: 0.1...8.0)
                data.append(GameActivityData(date: date, hours: hours))
            }
        }
        return data
    }
    
    static var previews: some View {
        CustomContributionGridView(activities: generatePreviewData())
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
#endif