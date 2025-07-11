import SwiftUI
import GRDB

struct ChartView: View {
    @StateObject private var databaseManager: MoriDatabaseManager
    @State private var collections: [ChartCollection] = []
    @State private var showingAddCollection = false
    @State private var errorMessage: String?
    
    init() {
        do {
            let manager = try MoriDatabaseManager()
            self._databaseManager = StateObject(wrappedValue: manager)
        } catch {
            // Fallback - this shouldn't happen in normal usage
            self._databaseManager = StateObject(wrappedValue: try! MoriDatabaseManager())
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if collections.isEmpty {
                    // Empty state content
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("暂无图表集合")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("点击右上角的添加按钮创建您的第一个图表集合")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                } else {
                    // Collections grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(collections, id: \.id) { collection in
                                CollectionCardView(collection: collection)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                
                // Error message display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("图表集合")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCollection = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddCollection) {
                AddCollectionView { collection in
                    saveCollection(collection)
                }
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    // MARK: - Database Operations
    
    private func loadCollections() {
        do {
            collections = try databaseManager.getAllCollections()
            errorMessage = nil
        } catch {
            errorMessage = "加载集合失败: \(error.localizedDescription)"
        }
    }
    
    private func saveCollection(_ collection: ChartCollection) {
        do {
            try databaseManager.createCollection(collection)
            loadCollections()
            errorMessage = nil
        } catch {
            errorMessage = "保存集合失败: \(error.localizedDescription)"
        }
    }
}

struct CollectionCardView: View {
    let collection: ChartCollection
    @State private var chartItemCount = 0
    
    var body: some View {
        NavigationLink(destination: CollectionDetailView(collection: collection)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(chartItemCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(collection.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                HStack {
                    Text("创建于")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(collection.creationDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadChartItemCount()
        }
    }
    
    private func loadChartItemCount() {
        // TODO: 从数据库加载图表项数量
        chartItemCount = 0
    }
}

struct AddCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var order = 0
    let onSave: (ChartCollection) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("集合信息") {
                    TextField("集合标题", text: $title)
                        .textFieldStyle(.plain)
                    
                    Stepper("排序顺序: \(order)", value: $order, in: 0...100)
                }
                
                Section("预览") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text(title.isEmpty ? "集合标题" : title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("排序: \(order)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("创建时间: \(Date().formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
            .navigationTitle("添加集合")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let collection = ChartCollection(title: title, order: order)
                        onSave(collection)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct CollectionDetailView: View {
    let collection: ChartCollection
    @StateObject private var databaseManager: MoriDatabaseManager
    @State private var chartItems: [ChartItem] = []
    @State private var showingAddChart = false
    @State private var showingDebugMenu = false
    @State private var errorMessage: String?
    
    init(collection: ChartCollection) {
        self.collection = collection
        do {
            let manager = try MoriDatabaseManager()
            self._databaseManager = StateObject(wrappedValue: manager)
        } catch {
            self._databaseManager = StateObject(wrappedValue: try! MoriDatabaseManager())
        }
    }
    
    var body: some View {
        VStack {
            if chartItems.isEmpty {
                // Empty state
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("暂无图表")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("点击右上角的添加按钮创建图表")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            } else {
                // Chart items list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chartItems, id: \.id) { item in
                            ChartItemRowView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            
            // Error message display
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Debug") {
                    showingDebugMenu = true
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddChart = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddChart) {
            AddChartItemView(collectionId: collection.id) { chartItem in
                saveChartItem(chartItem)
            }
        }
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView(collection: collection, databaseManager: databaseManager) {
                loadChartItems()
            }
        }
        .onAppear {
            loadChartItems()
        }
    }
    
    private func loadChartItems() {
        do {
            chartItems = try databaseManager.getChartItems(for: collection.id)
            errorMessage = nil
        } catch {
            errorMessage = "加载图表失败: \(error.localizedDescription)"
        }
    }
    
    private func saveChartItem(_ item: ChartItem) {
        do {
            try databaseManager.createChartItem(item)
            loadChartItems()
            errorMessage = nil
        } catch {
            errorMessage = "保存图表失败: \(error.localizedDescription)"
        }
    }
}

struct ChartItemRowView: View {
    let item: ChartItem
    @State private var contributionData: [ContributionGridData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Chart content
            if item.type == "contribution" {
                if !contributionData.isEmpty {
                    CustomContributionGridView(
                        activities: contributionData,
                        chartColorScheme: getChartColorScheme(from: item.colorTheme)
                    )
                    .frame(height: 120)
                    .padding(.bottom, 16)
                } else if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if !isLoading {
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
            if item.type == "contribution" {
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
}

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

struct DebugActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddChartItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedType = "contribution"
    @State private var selectedColorTheme = "blue"
    @State private var executionStatement = ""
    @State private var goal = 100
    @State private var dateRangeType = "lastYear"
    
    let collectionId: String
    let onSave: (ChartItem) -> Void
    
    let chartTypes = [
        ("contribution", "贡献图"),
        ("progress", "进度图"),
        ("bar", "柱状图")
    ]
    
    let colorThemes = [
        ("blue", "蓝色"),
        ("green", "绿色"),
        ("amber", "琥珀色"),
        ("rose", "玫瑰色"),
        ("purple", "紫色"),
        ("orange", "橙色"),
        ("teal", "青色"),
        ("slate", "灰色"),
        ("red", "红色"),
        ("indigo", "靛蓝色")
    ]
    
    let dateRangeTypes = [
        ("today", "今天"),
        ("thisWeek", "本周"),
        ("thisMonth", "本月"),
        ("thisYear", "今年"),
        ("lastYear", "去年"),
        ("custom", "自定义")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("图表标题", text: $title)
                        .textFieldStyle(.plain)
                    
                    Picker("图表类型", selection: $selectedType) {
                        ForEach(chartTypes, id: \.0) { type, name in
                            Text(name).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("颜色主题", selection: $selectedColorTheme) {
                        ForEach(colorThemes, id: \.0) { theme, name in
                            HStack {
                                Circle()
                                    .fill(getThemeColor(theme))
                                    .frame(width: 16, height: 16)
                                Text(name)
                            }
                            .tag(theme)
                        }
                    }
                }
                
                Section("设置") {
                    Picker("日期范围", selection: $dateRangeType) {
                        ForEach(dateRangeTypes, id: \.0) { type, name in
                            Text(name).tag(type)
                        }
                    }
                    
                    if selectedType == "progress" {
                        Stepper("目标值: \(goal)", value: $goal, in: 1...10000)
                    }
                }
                
                Section("数据源") {
                    TextField("SQL 查询语句", text: $executionStatement, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("示例: SELECT date, count FROM daily_activity WHERE date >= date('now', '-1 year')")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加图表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChart()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveChart() {
        let settings: ChartItemSetting = selectedType == "contribution" ?
            .contribution(ContributionChartSetting()) :
            .progress(ProgressChartSetting(goal: goal))
        
        let item = ChartItem(
            title: title,
            type: selectedType,
            colorTheme: selectedColorTheme,
            settings: settings,
            belongCollectionId: collectionId,
            executionStatement: executionStatement
        )
        
        onSave(item)
        dismiss()
    }
    
    private func getThemeColor(_ theme: String) -> Color {
        switch theme {
        case "blue":
            return Color("blue-500")
        case "green":
            return Color("green-500")
        case "amber":
            return Color("amber-500")
        case "rose":
            return Color("rose-500")
        case "purple":
            return Color("purple-500")
        case "orange":
            return Color("orange-500")
        case "teal":
            return Color("teal-500")
        case "slate":
            return Color("slate-500")
        case "red":
            return Color("red-500")
        case "indigo":
            return Color("indigo-500")
        default:
            return Color.gray
        }
    }
}

#Preview {
    ChartView()
}