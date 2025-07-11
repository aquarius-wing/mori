import SwiftUI

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    let collection: ChartCollection
    let databaseManager: MoriDatabaseManager
    let onDataChanged: () -> Void
    @State private var isProcessing = false
    @State private var resultMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("数据操作") {
                    DebugActionRow(
                        title: "添加游戏案例数据",
                        subtitle: "添加一个贡献图表，统计游戏时长",
                        icon: "gamecontroller.fill",
                        color: .blue
                    ) {
                        addGameSampleData()
                    }
                    
                    DebugActionRow(
                        title: "添加工作案例数据",
                        subtitle: "添加一个进度图表，统计工作进度",
                        icon: "briefcase.fill",
                        color: .green
                    ) {
                        addWorkSampleData()
                    }
                    
                    DebugActionRow(
                        title: "添加阅读案例数据",
                        subtitle: "添加一个贡献图表，统计阅读时长",
                        icon: "book.fill",
                        color: .purple
                    ) {
                        addReadingSampleData()
                    }
                }
                
                Section("测试功能") {
                    DebugActionRow(
                        title: "清空当前集合",
                        subtitle: "删除此集合中的所有图表项",
                        icon: "trash.fill",
                        color: .red
                    ) {
                        clearCollectionData()
                    }
                    
                    DebugActionRow(
                        title: "数据库统计",
                        subtitle: "查看数据库状态信息",
                        icon: "chart.bar.doc.horizontal",
                        color: .orange
                    ) {
                        showDatabaseStats()
                    }
                }
                
                if !resultMessage.isEmpty {
                    Section("执行结果") {
                        Text(resultMessage)
                            .font(.caption)
                            .foregroundColor(resultMessage.contains("失败") ? .red : .green)
                    }
                }
            }
            .navigationTitle("Debug 功能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Debug Actions
    
    private func addGameSampleData() {
        isProcessing = true
        resultMessage = ""
        
        let gameChartItem = ChartItem(
            title: "游戏",
            type: "contribution",
            colorTheme: "blue",
            settings: .contribution(ContributionChartSetting(dateRangeType: .lastYear)),
            belongCollectionId: collection.id,
            executionType: "sql",
            executionStatement: """
SELECT 
    DATE(startDate) AS event_date,
    SUM((JULIANDAY(endDate) - JULIANDAY(startDate)) * 24) AS total_hours
FROM calendar_events
WHERE title LIKE '%🎮%'
  AND endDate > startDate  -- 确保时长非负
GROUP BY DATE(startDate)
ORDER BY event_date ASC;
"""
        )
        
        do {
            try databaseManager.createChartItem(gameChartItem)
            resultMessage = "游戏案例数据添加成功"
            onDataChanged()
        } catch {
            resultMessage = "添加失败: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func addWorkSampleData() {
        isProcessing = true
        resultMessage = ""
        
        let workChartItem = ChartItem(
            title: "工作进度",
            type: "progress",
            colorTheme: "green",
            settings: .progress(ProgressChartSetting(goal: 8, dateRangeType: .thisMonth)),
            belongCollectionId: collection.id,
            executionType: "sql",
            executionStatement: """
SELECT 
    SUM((JULIANDAY(endDate) - JULIANDAY(startDate)) * 24) AS progress_hours
FROM calendar_events
WHERE (title LIKE '%工作%' OR title LIKE '%会议%' OR title LIKE '%开发%')
  AND DATE(startDate) >= DATE('now', 'start of month')
  AND endDate > startDate;
"""
        )
        
        do {
            try databaseManager.createChartItem(workChartItem)
            resultMessage = "工作案例数据添加成功"
            onDataChanged()
        } catch {
            resultMessage = "添加失败: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func addReadingSampleData() {
        isProcessing = true
        resultMessage = ""
        
        let readingChartItem = ChartItem(
            title: "阅读时长",
            type: "contribution",
            colorTheme: "purple",
            settings: .contribution(ContributionChartSetting(dateRangeType: .thisYear)),
            belongCollectionId: collection.id,
            executionType: "sql",
            executionStatement: """
SELECT 
    DATE(startDate) AS event_date,
    SUM((JULIANDAY(endDate) - JULIANDAY(startDate)) * 24) AS total_hours
FROM calendar_events
WHERE (title LIKE '%📚%' OR title LIKE '%阅读%' OR title LIKE '%读书%')
  AND endDate > startDate
GROUP BY DATE(startDate)
ORDER BY event_date ASC;
"""
        )
        
        do {
            try databaseManager.createChartItem(readingChartItem)
            resultMessage = "阅读案例数据添加成功"
            onDataChanged()
        } catch {
            resultMessage = "添加失败: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func clearCollectionData() {
        isProcessing = true
        resultMessage = ""
        
        do {
            let items = try databaseManager.getChartItems(for: collection.id)
            for item in items {
                try databaseManager.deleteChartItem(item.id)
            }
            resultMessage = "清空集合数据成功，删除了 \(items.count) 个图表项"
            onDataChanged()
        } catch {
            resultMessage = "清空失败: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func showDatabaseStats() {
        isProcessing = true
        resultMessage = ""
        
        let dbInfo = databaseManager.getDatabaseInfo()
        
        if let error = dbInfo["error"] as? String {
            resultMessage = "获取统计失败: \(error)"
        } else {
            let collectionsCount = dbInfo["chartCollectionCount"] as? Int ?? 0
            let itemsCount = dbInfo["chartItemCount"] as? Int ?? 0
            let tablesCount = dbInfo["tableCount"] as? Int ?? 0
            
            resultMessage = """
数据库统计:
- 集合数量: \(collectionsCount)
- 图表项数量: \(itemsCount)
- 数据表数量: \(tablesCount)
- 当前集合: \(collection.title)
"""
        }
        
        isProcessing = false
    }
}

#Preview {
    DebugMenuView(
        collection: ChartCollection(title: "示例集合", order: 0),
        databaseManager: try! MoriDatabaseManager()
    ) {
        // onDataChanged
    }
} 