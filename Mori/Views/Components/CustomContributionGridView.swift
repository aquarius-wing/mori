import SwiftUI

// MARK: - Color Extension for Chart Colors
extension ChartColorScheme {
    // Asset-based color system for contribution charts
    func getContributionColors() -> [Color] {
        switch self {
        case .blue:
            return [
                Color("blue-100"),  // Empty
                Color("blue-300"),  // Low
                Color("blue-500"),  // Medium
                Color("blue-600"),  // High
                Color("blue-700")   // Very High
            ]
            
        case .green:
            return [
                Color("green-100"),  // Empty
                Color("green-300"),  // Low
                Color("green-500"),  // Medium
                Color("green-600"),  // High
                Color("green-700")   // Very High
            ]
            
        case .amber:
            return [
                Color("amber-100"),  // Empty
                Color("amber-300"),  // Low
                Color("amber-500"),  // Medium
                Color("amber-600"),  // High
                Color("amber-700")   // Very High
            ]
            
        case .rose:
            return [
                Color("rose-100"),   // Empty
                Color("rose-300"),   // Low
                Color("rose-500"),   // Medium
                Color("rose-600"),   // High
                Color("rose-700")    // Very High
            ]
            
        case .purple:
            return [
                Color("purple-100"), // Empty
                Color("purple-300"), // Low
                Color("purple-500"), // Medium
                Color("purple-600"), // High
                Color("purple-700")  // Very High
            ]
            
        case .orange:
            return [
                Color("orange-100"), // Empty
                Color("orange-300"), // Low
                Color("orange-500"), // Medium
                Color("orange-600"), // High
                Color("orange-700")  // Very High
            ]
            
        case .teal:
            return [
                Color("teal-100"),   // Empty
                Color("teal-300"),   // Low
                Color("teal-500"),   // Medium
                Color("teal-600"),   // High
                Color("teal-700")    // Very High
            ]
            
        case .slate:
            return [
                Color("slate-100"),  // Empty
                Color("slate-300"),  // Low
                Color("slate-500"),  // Medium
                Color("slate-600"),  // High
                Color("slate-700")   // Very High
            ]
            
        case .red:
            return [
                Color("red-100"),    // Empty
                Color("red-300"),    // Low
                Color("red-500"),    // Medium
                Color("red-600"),    // High
                Color("red-700")     // Very High
            ]
            
        case .indigo:
            return [
                Color("indigo-100"), // Empty
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
        ScrollView {
            VStack(spacing: 20) {
                // Original themes
                VStack(alignment: .leading) {
                    Text("Blue Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .blue
                    )
                }
                
                VStack(alignment: .leading) {
                    Text("Green Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .green
                    )
                }
                
                VStack(alignment: .leading) {
                    Text("Amber Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .amber
                    )
                }
                
                VStack(alignment: .leading) {
                    Text("Rose Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .rose
                    )
                }
                
                VStack(alignment: .leading) {
                    Text("Purple Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .purple
                    )
                }

                VStack(alignment: .leading) {
                    Text("Orange Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .orange
                    )
                }

                VStack(alignment: .leading) {
                    Text("Teal Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .teal
                    )
                }

                VStack(alignment: .leading) {
                    Text("Slate Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .slate
                    )
                }

                VStack(alignment: .leading) {
                    Text("Red Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .red
                    )
                }

                VStack(alignment: .leading) {
                    Text("Indigo Theme")
                        .font(.headline)
                    CustomContributionGridView(
                        activities: generatePreviewData(),
                        chartColorScheme: .indigo
                    )
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
    }
}
#endif