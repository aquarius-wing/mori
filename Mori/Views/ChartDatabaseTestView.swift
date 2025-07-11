import SwiftUI

struct ChartDatabaseTestView: View {
    @StateObject private var databaseManager: MoriDatabaseManager
    @State private var collections: [ChartCollection] = []
    @State private var chartItems: [ChartItem] = []
    @State private var selectedCollection: ChartCollection?
    @State private var errorMessage: String?
    @State private var showingAddCollection = false
    @State private var showingAddChart = false
    
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
                // Error message display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Collections section
                collectionsSection
                
                // Chart items section
                chartItemsSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("图表数据库测试")
            .onAppear {
                loadData()
            }
        }
        .sheet(isPresented: $showingAddCollection) {
            AddCollectionView { collection in
                saveCollection(collection)
            }
        }
        .sheet(isPresented: $showingAddChart) {
            AddChartItemView(collections: collections) { chartItem in
                saveChartItem(chartItem)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var collectionsSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("图表集合")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("添加集合") {
                    showingAddCollection = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(collections, id: \.id) { collection in
                        CollectionCard(
                            collection: collection,
                            isSelected: selectedCollection?.id == collection.id
                        ) {
                            selectedCollection = collection
                            loadChartItems(for: collection.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var chartItemsSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("图表项目")
                    .font(.headline)
                    .fontWeight(.semibold)
                if selectedCollection != nil {
                    Text("- \(selectedCollection!.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("添加图表") {
                    showingAddChart = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chartItems, id: \.id) { item in
                        ChartItemCard(item: item) {
                            togglePin(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("创建示例数据") {
                createSampleData()
            }
            .foregroundColor(.green)
            
            Button("刷新数据") {
                loadData()
            }
            .foregroundColor(.blue)
            
            Button("清空数据") {
                clearAllData()
            }
            .foregroundColor(.red)
        }
        .padding()
    }
    
    // MARK: - Database Operations
    
    private func loadData() {
        do {
            collections = try databaseManager.getAllCollections()
            if let selected = selectedCollection {
                chartItems = try databaseManager.getChartItems(for: selected.id)
            } else {
                chartItems = try databaseManager.getAllChartItems()
            }
            errorMessage = nil
        } catch {
            errorMessage = "加载数据失败: \(error.localizedDescription)"
        }
    }
    
    private func loadChartItems(for collectionId: String) {
        do {
            chartItems = try databaseManager.getChartItems(for: collectionId)
            errorMessage = nil
        } catch {
            errorMessage = "加载图表项失败: \(error.localizedDescription)"
        }
    }
    
    private func saveCollection(_ collection: ChartCollection) {
        do {
            try databaseManager.createCollection(collection)
            loadData()
            errorMessage = nil
        } catch {
            errorMessage = "保存集合失败: \(error.localizedDescription)"
        }
    }
    
    private func saveChartItem(_ item: ChartItem) {
        do {
            try databaseManager.createChartItem(item)
            loadData()
            errorMessage = nil
        } catch {
            errorMessage = "保存图表项失败: \(error.localizedDescription)"
        }
    }
    
    private func togglePin(_ item: ChartItem) {
        do {
            try databaseManager.togglePinChartItem(item.id)
            loadData()
            errorMessage = nil
        } catch {
            errorMessage = "切换置顶状态失败: \(error.localizedDescription)"
        }
    }
    
    private func createSampleData() {
        do {
            try databaseManager.createSampleData()
            loadData()
            errorMessage = nil
        } catch {
            errorMessage = "创建示例数据失败: \(error.localizedDescription)"
        }
    }
    
    private func clearAllData() {
        do {
            let allCollections = try databaseManager.getAllCollections()
            for collection in allCollections {
                try databaseManager.deleteCollection(collection.id)
            }
            loadData()
            errorMessage = nil
        } catch {
            errorMessage = "清空数据失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct CollectionCard: View {
    let collection: ChartCollection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(collection.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("顺序: \(collection.order)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct ChartItemCard: View {
    let item: ChartItem
    let onTogglePin: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text("类型: \(item.type) | 主题: \(item.colorTheme)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !item.executionStatement.isEmpty {
                    Text(item.executionStatement)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onTogglePin) {
                Image(systemName: item.pinned ? "pin.slash.fill" : "pin.fill")
                    .font(.caption)
                    .foregroundColor(item.pinned ? .red : .gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
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
                TextField("集合标题", text: $title)
                Stepper("顺序: \(order)", value: $order, in: 0...100)
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

struct AddChartItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var type = "contribution"
    @State private var colorTheme = "blue"
    @State private var selectedCollectionId = ""
    @State private var order = 0
    @State private var executionStatement = ""
    
    let collections: [ChartCollection]
    let onSave: (ChartItem) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("图表标题", text: $title)
                
                Picker("类型", selection: $type) {
                    Text("Contribution").tag("contribution")
                    Text("Progress").tag("progress")
                    Text("Bar").tag("bar")
                }
                
                Picker("颜色主题", selection: $colorTheme) {
                    ForEach(ChartColorScheme.allCases, id: \.rawValue) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
                
                Picker("所属集合", selection: $selectedCollectionId) {
                    ForEach(collections, id: \.id) { collection in
                        Text(collection.title).tag(collection.id)
                    }
                }
                
                Stepper("顺序: \(order)", value: $order, in: 0...100)
                
                TextField("执行语句", text: $executionStatement, axis: .vertical)
                    .lineLimit(3...6)
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
                        let settings: ChartItemSetting = type == "contribution" ?
                            .contribution(ContributionChartSetting()) :
                            .progress(ProgressChartSetting())
                        
                        let item = ChartItem(
                            title: title,
                            type: type,
                            colorTheme: colorTheme,
                            settings: settings,
                            belongCollectionId: selectedCollectionId,
                            order: order,
                            executionStatement: executionStatement
                        )
                        onSave(item)
                        dismiss()
                    }
                    .disabled(title.isEmpty || selectedCollectionId.isEmpty)
                }
            }
        }
        .onAppear {
            if !collections.isEmpty && selectedCollectionId.isEmpty {
                selectedCollectionId = collections[0].id
            }
        }
    }
}

#Preview {
    ChartDatabaseTestView()
} 