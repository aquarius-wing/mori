import SwiftUI

// MARK: - Color Extension for Chart Colors
extension ChartColorScheme {
    // Asset-based color system for contribution charts
    func getContributionColors() -> [Color] {
        switch self {
        case .blue:
            return [
                Color("blue-50"),   // Empty
                Color("blue-100"),  // Low
                Color("blue-300"),  // Medium
                Color("blue-500"),  // High
                Color("blue-600")   // Very High
            ]
            
        case .green:
            return [
                Color("green-50"),   // Empty
                Color("green-100"),  // Low
                Color("green-300"),  // Medium
                Color("green-500"),  // High
                Color("green-700")   // Very High
            ]
            
        case .amber:
            return [
                Color("amber-50"),   // Empty
                Color("amber-100"),  // Low
                Color("amber-300"),  // Medium
                Color("amber-500"),  // High
                Color("amber-600")   // Very High
            ]
            
        case .rose:
            return [
                Color("rose-50"),    // Empty
                Color("rose-100"),   // Low
                Color("rose-300"),   // Medium
                Color("rose-500"),   // High
                Color("rose-600")    // Very High
            ]
            
        case .purple:
            return [
                Color("purple-50"),  // Empty
                Color("purple-100"), // Low
                Color("purple-300"), // Medium
                Color("purple-500"), // High
                Color("purple-600")  // Very High
            ]
            
        case .orange:
            return [
                Color("orange-50"),  // Empty
                Color("orange-100"), // Low
                Color("orange-300"), // Medium
                Color("orange-500"), // High
                Color("orange-600")  // Very High
            ]
            
        case .teal:
            return [
                Color("teal-50"),    // Empty
                Color("teal-100"),   // Low
                Color("teal-300"),   // Medium
                Color("teal-500"),   // High
                Color("teal-600")    // Very High
            ]
            
        case .slate:
            return [
                Color("slate-50"),   // Empty
                Color("slate-100"),  // Low
                Color("slate-300"),  // Medium
                Color("slate-500"),  // High
                Color("slate-600")   // Very High
            ]
            
        case .red:
            return [
                Color("red-50"),     // Empty
                Color("red-100"),    // Low
                Color("red-300"),    // Medium
                Color("red-500"),    // High
                Color("red-600")     // Very High
            ]
            
        case .indigo:
            return [
                Color("indigo-50"),  // Empty
                Color("indigo-100"), // Low
                Color("indigo-300"), // Medium
                Color("indigo-500"), // High
                Color("indigo-600")  // Very High
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
            // .background(
            //     RoundedRectangle(cornerRadius: 12)
            //         .fill(colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color.white)
            //         .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            // )
        }
        .padding(.trailing, 4)
        .frame(height: 150) // Fixed height for the contribution grid
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
                let count = dateCountMap[date] ?? 0
                let level = getContributionLevel(count: count)
                
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
        VStack(spacing: 20) {
            // Blue theme
            VStack(alignment: .leading) {
                Text("Blue Theme")
                    .font(.headline)
                CustomContributionGridView(
                    activities: generatePreviewData(),
                    chartColorScheme: .blue
                )
            }
            
            // Green theme
            VStack(alignment: .leading) {
                Text("Green Theme")
                    .font(.headline)
                CustomContributionGridView(
                    activities: generatePreviewData(),
                    chartColorScheme: .green
                )
            }
            
            // Amber theme
            VStack(alignment: .leading) {
                Text("Amber Theme")
                    .font(.headline)
                CustomContributionGridView(
                    activities: generatePreviewData(),
                    chartColorScheme: .amber
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif