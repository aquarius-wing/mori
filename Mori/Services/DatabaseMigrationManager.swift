import Foundation
import GRDB

// MARK: - Database Migration Manager

class DatabaseMigrationManager {
    static let shared = DatabaseMigrationManager()
    
    private init() {}
    
    // Apply all migrations to a database
    func applyMigrations(to database: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        
        // Register all migrations
        registerMigrations(&migrator)
        
        // Apply migrations
        try migrator.migrate(database)
    }
    
    // Register all migrations
    private func registerMigrations(_ migrator: inout DatabaseMigrator) {
        // Migration 1: Create chart collections and items tables
        migrator.registerMigration("v1_create_chart_tables") { db in
            // Create chart_collections table
            try db.create(table: ChartCollection.databaseTableName, ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("order", .integer).notNull().defaults(to: 0)
                t.column("creationDate", .datetime).notNull()
                t.column("lastModifiedDate", .datetime).notNull()
            }
            
            // Create chart_items table
            try db.create(table: ChartItem.databaseTableName, ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("type", .text).notNull()
                t.column("colorTheme", .text).notNull()
                t.column("settings", .text).notNull() // JSON string
                t.column("belongCollectionId", .text).notNull()
                t.column("order", .integer).notNull().defaults(to: 0)
                t.column("executionType", .text).notNull().defaults(to: "sql")
                t.column("executionStatement", .text).notNull().defaults(to: "")
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("creationDate", .datetime).notNull()
                t.column("lastModifiedDate", .datetime).notNull()
                
                // Foreign key constraint
                t.foreignKey(["belongCollectionId"], references: ChartCollection.databaseTableName, columns: ["id"], onDelete: .cascade)
            }
        }
        
        // Migration 2: Create indexes for performance
        migrator.registerMigration("v2_create_indexes") { db in
            try db.create(index: "idx_chart_items_collection", on: ChartItem.databaseTableName, columns: ["belongCollectionId"], ifNotExists: true)
            try db.create(index: "idx_chart_items_pinned", on: ChartItem.databaseTableName, columns: ["pinned"], ifNotExists: true)
            try db.create(index: "idx_chart_items_order", on: ChartItem.databaseTableName, columns: ["order"], ifNotExists: true)
            try db.create(index: "idx_chart_collections_order", on: ChartCollection.databaseTableName, columns: ["order"], ifNotExists: true)
        }
        
        // Migration 3: Add any future schema changes
        // migrator.registerMigration("v3_add_new_columns") { db in
        //     try db.alter(table: ChartItem.databaseTableName) { t in
        //         t.add(column: "newColumn", .text)
        //     }
        // }
    }
}

// MARK: - Database Helper

extension DatabaseMigrationManager {
    // Check if database is at the latest version
    func isDatabaseUpToDate(database: DatabaseQueue) -> Bool {
        do {
            let appliedMigrations = try database.read { db in
                try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
            }
            
            // Check if all expected migrations are applied
            let expectedMigrations = [
                "v1_create_chart_tables",
                "v2_create_indexes"
            ]
            
            return expectedMigrations.allSatisfy { appliedMigrations.contains($0) }
        } catch {
            return false
        }
    }
    
    // Get database version info
    func getDatabaseInfo(database: DatabaseQueue) -> [String: Any] {
        do {
            return try database.read { db in
                let appliedMigrations = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
                let tableCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'") ?? 0
                let chartCollectionCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(ChartCollection.databaseTableName)") ?? 0
                let chartItemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(ChartItem.databaseTableName)") ?? 0
                
                return [
                    "appliedMigrations": appliedMigrations,
                    "tableCount": tableCount,
                    "chartCollectionCount": chartCollectionCount,
                    "chartItemCount": chartItemCount
                ]
            }
        } catch {
            return [
                "error": error.localizedDescription
            ]
        }
    }
} 