import SwiftUI

// MARK: - Color Extension for Chart Colors
extension ChartColorScheme {
    // Asset-based color system for contribution charts
    func getContributionColors() -> [Color] {
        switch self {
        case .blue:
            return [
                Color("blue-50"),  // Empty
                Color("blue-300"),  // Low
                Color("blue-500"),  // Medium
                Color("blue-600"),  // High
                Color("blue-700")   // Very High
            ]
            
        case .green:
            return [
                Color("green-50"),  // Empty
                Color("green-300"),  // Low
                Color("green-500"),  // Medium
                Color("green-600"),  // High
                Color("green-700")   // Very High
            ]
            
        case .amber:
            return [
                Color("amber-50"),  // Empty
                Color("amber-300"),  // Low
                Color("amber-500"),  // Medium
                Color("amber-600"),  // High
                Color("amber-700")   // Very High
            ]
            
        case .rose:
            return [
                Color("rose-50"),   // Empty
                Color("rose-300"),   // Low
                Color("rose-500"),   // Medium
                Color("rose-600"),   // High
                Color("rose-700")    // Very High
            ]
            
        case .purple:
            return [
                Color("purple-50"), // Empty
                Color("purple-300"), // Low
                Color("purple-500"), // Medium
                Color("purple-600"), // High
                Color("purple-700")  // Very High
            ]
            
        case .orange:
            return [
                Color("orange-50"), // Empty
                Color("orange-300"), // Low
                Color("orange-500"), // Medium
                Color("orange-600"), // High
                Color("orange-700")  // Very High
            ]
            
        case .teal:
            return [
                Color("teal-50"),   // Empty
                Color("teal-300"),   // Low
                Color("teal-500"),   // Medium
                Color("teal-600"),   // High
                Color("teal-700")    // Very High
            ]
            
        case .slate:
            return [
                Color("slate-50"),  // Empty
                Color("slate-300"),  // Low
                Color("slate-500"),  // Medium
                Color("slate-600"),  // High
                Color("slate-700")   // Very High
            ]
            
        case .red:
            return [
                Color("red-50"),    // Empty
                Color("red-300"),    // Low
                Color("red-500"),    // Medium
                Color("red-600"),    // High
                Color("red-700")     // Very High
            ]
            
        case .indigo:
            return [
                Color("indigo-50"), // Empty
                Color("indigo-300"), // Low
                Color("indigo-500"), // Medium
                Color("indigo-600"), // High
                Color("indigo-700")  // Very High
            ]
        }
    }
}

struct CustomContributionGridView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let activities: [ContributionGridData]
    let chartColorScheme: ChartColorScheme
    
    // Use @State to cache the computed result and avoid recalculation
    @State private var dateCountMap: [Date: Double] = [:]
    
    // Helper function to compute dateCountMap
    private func computeDateCountMap() -> [Date: Double] {
        var calendar = Calendar.current
        // time zone is UTC
        calendar.timeZone = TimeZone.current
        var map: [Date: Double] = [:]
        for activity in activities {
            let dayStart = calendar.startOfDay(for: activity.date)
            map[dayStart, default: 0] += activity.count
        }
        return map
    }
    
    private var contributionColors: [Color] {
        return chartColorScheme.getContributionColors()
    }
    
    var body: some View {
        let heightOfMonthHeader: CGFloat = 24
        let weekdayLabelWidth: CGFloat = 15
        let squareSize: CGFloat = 12
        let spacing: CGFloat = 3
        let heightOfGrid: CGFloat = 7 * squareSize + 6 * spacing
        GeometryReader { geometry in
            let availableWidth = geometry.size.width // Account for padding
            let gridWidth = availableWidth - weekdayLabelWidth - spacing
            let maxColumns = Int((gridWidth + spacing) / (squareSize + spacing))
            let actualColumns = min(maxColumns, 53) // Don't exceed 53 weeks
            
            VStack(alignment: .leading, spacing: 4) {
                // Month labels using grid layout
                monthHeaderGridView(columns: actualColumns, squareSize: squareSize, spacing: spacing)
                
                // Main grid with weekday labels
                HStack(alignment: .top, spacing: spacing) {
                    weekdayLabelsView(squareSize: squareSize, spacing: spacing)
                    contributionGridView(columns: actualColumns, squareSize: squareSize, spacing: spacing)
                }
            }
        }
        .padding(.trailing, 4)
        .frame(height: heightOfMonthHeader + 4 + heightOfGrid)
        .onAppear {
            // Compute dateCountMap when view appears
            dateCountMap = computeDateCountMap()
        }
        .onChange(of: activities) { _ in
            // Recompute when activities change
            dateCountMap = computeDateCountMap()
        }
    }

    // MARK: - Subviews
    
    private func monthHeaderGridView(columns: Int, squareSize: CGFloat, spacing: CGFloat) -> some View {
        let calendar = Calendar.current
        let startDate = getStartDate(actualColumns: columns)
        let monthSymbols = calendar.shortMonthSymbols
        
        // Calculate month segments with actual spans
        let monthSegments = calculateMonthSegments(columns: columns, startDate: startDate, calendar: calendar)
        
        return HStack(spacing: 0) {
            Spacer().frame(width: 24 + spacing) // Space for weekday labels
            
            HStack(spacing: spacing) {
                ForEach(monthSegments.indices, id: \.self) { index in
                    let segment = monthSegments[index]
                    let spanWidth = CGFloat(segment.columnCount) * squareSize + CGFloat(max(0, segment.columnCount - 1)) * spacing
                    
                    Text(monthSymbols[segment.month - 1])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: spanWidth, alignment: .leading)
                }
            }
        }
    }
    
    // Helper struct for month segments
    private struct MonthSegment {
        let month: Int
        let startColumn: Int
        let columnCount: Int
    }
    
    // Calculate actual month spans
    private func calculateMonthSegments(columns: Int, startDate: Date, calendar: Calendar) -> [MonthSegment] {
        var segments: [MonthSegment] = []
        var currentMonth: Int? = nil
        var currentStartColumn = 0
        var currentColumnCount = 0
        
        for column in 0..<columns {
            let weekDate = calendar.date(byAdding: .weekOfYear, value: column, to: startDate)!
            let monthOfWeek = calendar.component(.month, from: weekDate)
            
            if currentMonth == nil {
                // First month
                currentMonth = monthOfWeek
                currentStartColumn = column
                currentColumnCount = 1
            } else if currentMonth == monthOfWeek {
                // Same month, increment count
                currentColumnCount += 1
            } else {
                // New month, save previous segment
                segments.append(MonthSegment(
                    month: currentMonth!,
                    startColumn: currentStartColumn,
                    columnCount: currentColumnCount
                ))
                
                // Start new month
                currentMonth = monthOfWeek
                currentStartColumn = column
                currentColumnCount = 1
            }
        }
        
        // Add the last segment
        if let month = currentMonth {
            segments.append(MonthSegment(
                month: month,
                startColumn: currentStartColumn,
                columnCount: currentColumnCount
            ))
        }
        
        return segments
    }
    
    private func weekdayLabelsView(squareSize: CGFloat, spacing: CGFloat) -> some View {
        let weekdays = ["Mon", "Wed", "Fri"]
        
        return VStack(spacing: spacing) {
            ForEach(weekdays.indices, id: \.self) { index in
                Text(weekdays[index])
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                    .frame(height: squareSize * 2 + 3, alignment: .bottom)
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
                let count = dateCountMap[date] ?? 0
                let level = getContributionLevel(count: count)
                
                Rectangle()
                    .fill(contributionColors[level])
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(12)
            }
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
    
    private func getContributionLevel(count: Double) -> Int {
        switch count {
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
    static func generatePreviewData() -> [ContributionGridData] {
        var data: [ContributionGridData] = []
        let calendar = Calendar.current
        for i in 0..<365 {
            if Bool.random() {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let count = Double.random(in: 0.1...8.0)
                data.append(ContributionGridData(date: date, count: count))
            }
        }
        return data
    }
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Show all available color schemes
                ForEach(ChartColorScheme.allCases.indices, id: \.self) { index in
                    previewCard(for: index)
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
    }
    
    // Break down complex expression into separate view
    private static func previewCard(for index: Int) -> some View {
        let colorScheme = ChartColorScheme.allCases[index]
        let title = colorScheme.displayName
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            CustomContributionGridView(
                activities: generatePreviewData(),
                chartColorScheme: colorScheme
            )
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private static var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
#endif
