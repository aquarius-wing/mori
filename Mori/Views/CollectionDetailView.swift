import SwiftUI

struct CollectionDetailView: View {
    let collection: ChartCollection
    @StateObject private var databaseManager: MoriDatabaseManager
    @State private var chartItems: [ChartItem] = []
    @State private var showingAddChart = false
    @State private var showingDebugMenu = false
    @State private var errorMessage: String?
    private let previewMode: Bool
    private let previewItems: [ChartItem]
    
    init(collection: ChartCollection) {
        self.collection = collection
        self.previewMode = false
        self.previewItems = []
        do {
            let manager = try MoriDatabaseManager()
            self._databaseManager = StateObject(wrappedValue: manager)
        } catch {
            self._databaseManager = StateObject(wrappedValue: try! MoriDatabaseManager())
        }
    }
    
    // Preview initializer with demo data
    init(collection: ChartCollection, previewItems: [ChartItem]) {
        self.collection = collection
        self.previewMode = true
        self.previewItems = previewItems
        // Create a dummy database manager for preview
        self._databaseManager = StateObject(wrappedValue: try! MoriDatabaseManager())
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
                        ForEach(chartItems.indices, id: \.self) { index in
                            ChartItemRowView(item: chartItems[index])
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
        // In preview mode, use the provided preview items
        if previewMode {
            chartItems = previewItems
            return
        }
        
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

#Preview {
    let collection = ChartCollection(title: "示例集合", order: 0)
    let demoChartItem = ChartItem(
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
    
    return NavigationStack {
        CollectionDetailView(collection: collection, previewItems: [demoChartItem])
    }
} 