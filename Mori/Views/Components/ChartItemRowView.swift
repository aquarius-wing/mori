import SwiftUI
import GRDB

struct ChartItemRowView: View {
    let item: ChartItem
    let previewMode: Bool
    @State private var contributionData: [ContributionGridData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(item: ChartItem, previewMode: Bool = false) {
        self.item = item
        self.previewMode = previewMode
    }
    
    private var databasePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("CalendarSync.sqlite").path
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if item.pinned {
                        Label("已置顶", systemImage: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if item.type != "contribution" {
                    Image(systemName: getChartIcon(for: item.type))
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else if isLoading && !previewMode {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Chart content
            if item.type == "contribution" {
                let dataToShow = previewMode ? Self.generateSampleContributionData() : contributionData
                let chartColorScheme = getChartColorScheme(from: item.colorTheme)
                if !dataToShow.isEmpty {
                    CustomContributionGridView(
                        activities: dataToShow,
                        chartColorScheme: chartColorScheme
                    )
                } else if let errorMessage = errorMessage, !previewMode {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if !isLoading && !previewMode {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.secondary)
                        Text("暂无数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onAppear {
            if item.type == "contribution" && !previewMode {
                executeContributionQuery()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func executeContributionQuery() {
        guard !item.executionStatement.isEmpty else {
            errorMessage = "SQL 查询语句为空"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let queryResults = try executeQueryOnCalendarDatabase(item.executionStatement)
                let contributionResults = convertQueryToContributionData(queryResults)
                
                DispatchQueue.main.async {
                    self.contributionData = contributionResults
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "查询失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func executeQueryOnCalendarDatabase(_ query: String) throws -> [[String: Any]] {
        let dbQueue = try DatabaseQueue(path: databasePath)
        
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: query)
            return rows.map { row in
                var dict: [String: Any] = [:]
                for (index, column) in row.columnNames.enumerated() {
                    dict[column] = row[index]
                }
                return dict
            }
        }
    }
    
    private func convertQueryToContributionData(_ queryResults: [[String: Any]]) -> [ContributionGridData] {
        var contributionData: [ContributionGridData] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for row in queryResults {
            // Try to extract date and count from the query result
            var date: Date?
            var count: Double = 0
            
            // Look for date fields (common field names)
            for (key, value) in row {
                let lowercaseKey = key.lowercased()
                
                // Try to find date field
                if lowercaseKey.contains("date") || lowercaseKey.contains("event_date") {
                    if let dateString = value as? String {
                        date = dateFormatter.date(from: dateString)
                    } else if let dateValue = value as? Date {
                        date = dateValue
                    }
                }
                
                // Try to find count/value field
                if lowercaseKey.contains("hour") || lowercaseKey.contains("count") || 
                   lowercaseKey.contains("total") || lowercaseKey.contains("value") {
                    if let doubleValue = value as? Double {
                        count = doubleValue
                    } else if let intValue = value as? Int {
                        count = Double(intValue)
                    } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                        count = doubleValue
                    }
                }
            }
            
            // If we found both date and count, add to results
            if let validDate = date {
                contributionData.append(ContributionGridData(date: validDate, count: count))
            }
        }
        
        return contributionData
    }
    
    // MARK: - Helper Functions
    
    private func getChartIcon(for type: String) -> String {
        switch type {
        case "contribution":
            return "square.grid.3x3"
        case "progress":
            return "chart.pie"
        case "bar":
            return "chart.bar"
        case "line":
            return "chart.line.uptrend.xyaxis"
        default:
            return "chart.bar.xaxis"
        }
    }
    
    private func getChartColorScheme(from colorTheme: String) -> ChartColorScheme {
        switch colorTheme {
        case "blue":
            return .blue
        case "green":
            return .green
        case "amber":
            return .amber
        case "rose":
            return .rose
        case "purple":
            return .purple
        case "orange":
            return .orange
        case "teal":
            return .teal
        case "slate":
            return .slate
        case "red":
            return .red
        case "indigo":
            return .indigo
        default:
            return .blue
        }
    }
    
    // MARK: - Sample Data for Preview
    
    static func generateSampleContributionData() -> [ContributionGridData] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let today = Date()
        let dayCount = 365 // Last year of data
        
        return (0..<dayCount).map { index in
            let date = calendar.date(byAdding: .day, value: -(dayCount - 1 - index), to: today) ?? today
            let count = Double(Int.random(in: 0...4)) // Random activity level from 0 to 4
            return ContributionGridData(date: date, count: count)
        }
    }
}

#Preview {
    ChartItemRowView(
        item: ChartItem(
            title: "示例图表",
            type: "contribution",
            colorTheme: "blue",
            settings: .contribution(ContributionChartSetting()),
            belongCollectionId: "test",
            executionStatement: ""
        ),
        previewMode: true
    )
    .padding()
} 
