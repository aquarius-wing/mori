import Foundation
import GRDB

// MARK: - Mori Database Manager

class MoriDatabaseManager: ObservableObject {
    private let dbQueue: DatabaseQueue
    
    init() throws {
        // Get the documents directory path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent("mori.db").path
        
        // Create database queue
        dbQueue = try DatabaseQueue(path: dbPath)
        
        // Apply database migrations
        try DatabaseMigrationManager.shared.applyMigrations(to: dbQueue)
    }
    

    
    // MARK: - Chart Collection Operations
    
    func createCollection(_ collection: ChartCollection) throws {
        try dbQueue.write { db in
            try collection.insert(db)
        }
    }
    
    func updateCollection(_ collection: ChartCollection) throws {
        try dbQueue.write { db in
            var mutableCollection = collection
            mutableCollection.willUpdate()
            try mutableCollection.update(db)
        }
    }
    
    func deleteCollection(_ id: String) throws {
        try dbQueue.write { db in
            try ChartCollection.deleteOne(db, key: id)
        }
    }
    
    func getCollection(by id: String) throws -> ChartCollection? {
        try dbQueue.read { db in
            try ChartCollection.fetchOne(db, key: id)
        }
    }
    
    func getAllCollections() throws -> [ChartCollection] {
        try dbQueue.read { db in
            try ChartCollection
                .order(ChartCollection.Columns.order.asc)
                .fetchAll(db)
        }
    }
    
    // MARK: - Chart Item Operations
    
    func createChartItem(_ item: ChartItem) throws {
        try dbQueue.write { db in
            try item.insert(db)
        }
    }
    
    func updateChartItem(_ item: ChartItem) throws {
        try dbQueue.write { db in
            var mutableItem = item
            mutableItem.willUpdate()
            try mutableItem.update(db)
        }
    }
    
    func deleteChartItem(_ id: String) throws {
        try dbQueue.write { db in
            try ChartItem.deleteOne(db, key: id)
        }
    }
    
    func getChartItem(by id: String) throws -> ChartItem? {
        try dbQueue.read { db in
            try ChartItem.fetchOne(db, key: id)
        }
    }
    
    func getChartItems(for collectionId: String) throws -> [ChartItem] {
        try dbQueue.read { db in
            try ChartItem
                .filter(ChartItem.Columns.belongCollectionId == collectionId)
                .order(ChartItem.Columns.order.asc)
                .fetchAll(db)
        }
    }
    
    func getAllChartItems() throws -> [ChartItem] {
        try dbQueue.read { db in
            try ChartItem
                .order(ChartItem.Columns.order.asc)
                .fetchAll(db)
        }
    }
    
    func getPinnedChartItems() throws -> [ChartItem] {
        try dbQueue.read { db in
            try ChartItem
                .filter(ChartItem.Columns.pinned == true)
                .order(ChartItem.Columns.order.asc)
                .fetchAll(db)
        }
    }
    
    func togglePinChartItem(_ id: String) throws {
        try dbQueue.write { db in
            if var item = try ChartItem.fetchOne(db, key: id) {
                item.pinned.toggle()
                item.willUpdate()
                try item.update(db)
            }
        }
    }
    
    func updateChartItemOrder(_ id: String, newOrder: Int) throws {
        try dbQueue.write { db in
            if var item = try ChartItem.fetchOne(db, key: id) {
                item.order = newOrder
                item.willUpdate()
                try item.update(db)
            }
        }
    }
    
    func updateCollectionOrder(_ id: String, newOrder: Int) throws {
        try dbQueue.write { db in
            if var collection = try ChartCollection.fetchOne(db, key: id) {
                collection.order = newOrder
                collection.willUpdate()
                try collection.update(db)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func executeCustomQuery(_ query: String) throws -> [[String: Any]] {
        try dbQueue.read { db in
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
    
    func getDatabaseInfo() -> [String: Any] {
        return DatabaseMigrationManager.shared.getDatabaseInfo(database: dbQueue)
    }
    
    func isDatabaseUpToDate() -> Bool {
        return DatabaseMigrationManager.shared.isDatabaseUpToDate(database: dbQueue)
    }
    
    func getCollectionWithItems(_ collectionId: String) throws -> (collection: ChartCollection, items: [ChartItem])? {
        try dbQueue.read { db in
            guard let collection = try ChartCollection.fetchOne(db, key: collectionId) else {
                return nil
            }
            
            let items = try ChartItem
                .filter(ChartItem.Columns.belongCollectionId == collectionId)
                .order(ChartItem.Columns.order.asc)
                .fetchAll(db)
            
            return (collection: collection, items: items)
        }
    }
}

// MARK: - Extensions

extension MoriDatabaseManager {
    // Sample data creation method for testing
    func createSampleData() throws {
        // Create default collection
        let defaultCollection = ChartCollection(
            title: "Default Collection",
            order: 0
        )
        try createCollection(defaultCollection)
        
        // Create sample chart items
        let contributionItem = ChartItem(
            title: "Daily Activity",
            type: "contribution",
            colorTheme: "blue",
            settings: .contribution(ContributionChartSetting(dateRangeType: .lastYear)),
            belongCollectionId: defaultCollection.id,
            order: 0,
            executionType: "sql",
            executionStatement: "SELECT date, count FROM activity_log WHERE date >= date('now', '-1 year')",
            pinned: true
        )
        
        let progressItem = ChartItem(
            title: "Monthly Goal",
            type: "progress",
            colorTheme: "green",
            settings: .progress(ProgressChartSetting(goal: 100, dateRangeType: .thisMonth)),
            belongCollectionId: defaultCollection.id,
            order: 1,
            executionType: "sql",
            executionStatement: "SELECT SUM(value) as progress FROM monthly_goals WHERE month = date('now', 'start of month')",
            pinned: false
        )
        
        try createChartItem(contributionItem)
        try createChartItem(progressItem)
    }
} 