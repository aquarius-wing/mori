import Foundation
import SwiftUI
import GRDB

// MARK: - Data Models

// Contribution Grid Data model
struct ContributionGridData: Identifiable, Codable, Equatable {
    let id = UUID()
    let date: Date
    let count: Double
    
    init(date: Date, count: Double) {
        self.date = date
        self.count = count
    }
    
    // Custom Equatable implementation to compare by date and count only
    static func == (lhs: ContributionGridData, rhs: ContributionGridData) -> Bool {
        return lhs.date == rhs.date && lhs.count == rhs.count
    }
}

// Chart Color Scheme enum - supports all Shadcn colors
enum ChartColorScheme: String, CaseIterable {
    case blue = "blue"
    case green = "green"
    case amber = "amber"
    case rose = "rose"
    case purple = "purple"
    case orange = "orange"
    case teal = "teal"
    case slate = "slate"
    case red = "red"
    case indigo = "indigo"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// Chart Type enum
enum ChartType: String, CaseIterable {
    case contribution = "contribution"
    case bar = "bar"
    case line = "line"
    case pie = "pie"
    case progress = "progress"
    
    var displayName: String {
        switch self {
        case .contribution:
            return "Contribution Grid"
        case .bar:
            return "Bar Chart"
        case .line:
            return "Line Chart"
        case .pie:
            return "Pie Chart"
        case .progress:
            return "Progress Chart"
        }
    }
}

// MARK: - Chart Item Settings

// Base setting protocol
protocol ChartItemSettingType: Codable, Equatable {
    var settingType: String { get }
}

// Date Range Type enum
enum DateRangeType: String, CaseIterable, Codable {
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case thisYear = "this_year"
    case lastYear = "last_year"
    case customMonth = "custom_month"
    case customYear = "custom_year"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .thisWeek:
            return "This Week"
        case .thisMonth:
            return "This Month"
        case .thisYear:
            return "This Year"
        case .lastYear:
            return "Last Year"
        case .customMonth:
            return "Custom Month"
        case .customYear:
            return "Custom Year"
        case .custom:
            return "Custom"
        }
    }
}

// Contribution Chart Settings
struct ContributionChartSetting: ChartItemSettingType {
    let settingType = "contribution"
    var dateRangeType: DateRangeType
    var dateRangeCustom: String? // ISO 8601 date range string
    
    init(dateRangeType: DateRangeType = .lastYear, dateRangeCustom: String? = nil) {
        self.dateRangeType = dateRangeType
        self.dateRangeCustom = dateRangeCustom
    }
}

// Progress Chart Settings
struct ProgressChartSetting: ChartItemSettingType {
    let settingType = "progress"
    var goal: Int
    var dateRangeType: DateRangeType
    var dateRangeCustom: String? // ISO 8601 date range string
    
    init(goal: Int = 100, dateRangeType: DateRangeType = .thisMonth, dateRangeCustom: String? = nil) {
        self.goal = goal
        self.dateRangeType = dateRangeType
        self.dateRangeCustom = dateRangeCustom
    }
}

// Generic Chart Settings wrapper
enum ChartItemSetting: Codable, Equatable {
    case contribution(ContributionChartSetting)
    case progress(ProgressChartSetting)
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "contribution":
            let setting = try container.decode(ContributionChartSetting.self, forKey: .data)
            self = .contribution(setting)
        case "progress":
            let setting = try container.decode(ProgressChartSetting.self, forKey: .data)
            self = .progress(setting)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown chart setting type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .contribution(let setting):
            try container.encode("contribution", forKey: .type)
            try container.encode(setting, forKey: .data)
        case .progress(let setting):
            try container.encode("progress", forKey: .type)
            try container.encode(setting, forKey: .data)
        }
    }
}

// Extension for ChartItemSetting to support GRDB
extension ChartItemSetting: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        do {
            let data = try JSONEncoder().encode(self)
            return data.databaseValue
        } catch {
            return DatabaseValue.null
        }
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ChartItemSetting? {
        guard let data = Data.fromDatabaseValue(dbValue) else { return nil }
        return try? JSONDecoder().decode(ChartItemSetting.self, from: data)
    }
}

// MARK: - Database Models

// Chart Collection - Database Model
struct ChartCollection: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var order: Int
    var creationDate: Date
    var lastModifiedDate: Date
    
    init(id: String = UUID().uuidString, title: String, order: Int = 0) {
        self.id = id
        self.title = title
        self.order = order
        self.creationDate = Date()
        self.lastModifiedDate = Date()
    }
    
    // GRDB table configuration
    static let databaseTableName = "chart_collections"
    
    // Define columns
    enum Columns: String, ColumnExpression {
        case id, title, order, creationDate, lastModifiedDate
    }
    
    // Update lastModifiedDate before saving
    mutating func willUpdate() {
        lastModifiedDate = Date()
    }
}

// Chart Item - Database Model
struct ChartItem: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var type: String
    var colorTheme: String
    var settings: ChartItemSetting
    var belongCollectionId: String
    var order: Int
    var executionType: String
    var executionStatement: String
    var pinned: Bool
    var creationDate: Date
    var lastModifiedDate: Date
    
    init(
        id: String = UUID().uuidString,
        title: String,
        type: String,
        colorTheme: String,
        settings: ChartItemSetting,
        belongCollectionId: String,
        order: Int = 0,
        executionType: String = "sql",
        executionStatement: String = "",
        pinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.colorTheme = colorTheme
        self.settings = settings
        self.belongCollectionId = belongCollectionId
        self.order = order
        self.executionType = executionType
        self.executionStatement = executionStatement
        self.pinned = pinned
        self.creationDate = Date()
        self.lastModifiedDate = Date()
    }
    
    // GRDB table configuration
    static let databaseTableName = "chart_items"
    
    // Define columns
    enum Columns: String, ColumnExpression {
        case id, title, type, colorTheme, settings, belongCollectionId, order
        case executionType, executionStatement, pinned, creationDate, lastModifiedDate
    }
    
    // Update lastModifiedDate before saving
    mutating func willUpdate() {
        lastModifiedDate = Date()
    }
}

// MARK: - View Models (renamed from original ChartItem)

// Chart Item View Model for UI
struct ChartItemViewModel: Identifiable {
    let id = UUID()
    let title: String
    let type: ChartType
    let colorScheme: ChartColorScheme
    let data: [Int] // Sample data for demonstration
    
    // Sample data
    static let sampleData: [ChartItemViewModel] = [
        ChartItemViewModel(title: "Activity Overview", type: .contribution, colorScheme: .blue, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Green Theme", type: .contribution, colorScheme: .green, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Amber Style", type: .contribution, colorScheme: .amber, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Rose Theme", type: .contribution, colorScheme: .rose, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Purple Scheme", type: .contribution, colorScheme: .purple, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Orange Theme", type: .contribution, colorScheme: .orange, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Teal Style", type: .contribution, colorScheme: .teal, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Slate Theme", type: .contribution, colorScheme: .slate, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Red Scheme", type: .contribution, colorScheme: .red, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItemViewModel(title: "Indigo Style", type: .contribution, colorScheme: .indigo, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) })
    ]
    
    // Sample data with various realistic patterns for better preview
    static let sampleDataWithVariousPatterns: [ChartItemViewModel] = [
        // High activity pattern - busy developer
        ChartItemViewModel(
            title: "High Activity Developer",
            type: .contribution,
            colorScheme: .blue,
            data: Array(0..<365).map { day in
                let dayOfWeek = day % 7
                // Weekend less activity
                if dayOfWeek == 0 || dayOfWeek == 6 {
                    return Int.random(in: 0...2)
                } else {
                    return Int.random(in: 2...4)
                }
            }
        ),
        
        // Learning curve pattern - gradual improvement
        ChartItemViewModel(
            title: "Learning Journey",
            type: .contribution,
            colorScheme: .green,
            data: Array(0..<365).map { day in
                let progress = Double(day) / 365.0
                let baseActivity = Int(progress * 3) // 0 to 3 based on progress
                let randomVariation = Int.random(in: -1...1)
                return max(0, min(4, baseActivity + randomVariation))
            }
        ),
        
        // Sprint pattern - intense bursts followed by rest
        ChartItemViewModel(
            title: "Sprint Work Pattern",
            type: .contribution,
            colorScheme: .amber,
            data: Array(0..<365).map { day in
                let sprintCycle = day % 14 // 2-week sprints
                if sprintCycle < 10 {
                    return Int.random(in: 2...4) // Active sprint days
                } else {
                    return Int.random(in: 0...1) // Rest/planning days
                }
            }
        ),
        
        // Declining activity - burnout pattern
        ChartItemViewModel(
            title: "Declining Activity",
            type: .contribution,
            colorScheme: .rose,
            data: Array(0..<365).map { day in
                let progress = 1.0 - (Double(day) / 365.0)
                let baseActivity = Int(progress * 4)
                let randomVariation = Int.random(in: -1...1)
                return max(0, min(4, baseActivity + randomVariation))
            }
        ),
        
        // Seasonal pattern - more active in certain months
        ChartItemViewModel(
            title: "Seasonal Activity",
            type: .contribution,
            colorScheme: .purple,
            data: Array(0..<365).map { day in
                let month = (day / 30) % 12
                let seasonalMultiplier: Double
                // More active in winter months (coding season)
                if month >= 10 || month <= 2 {
                    seasonalMultiplier = 1.0
                } else if month >= 6 && month <= 8 {
                    seasonalMultiplier = 0.3 // Summer break
                } else {
                    seasonalMultiplier = 0.7
                }
                let baseActivity = Int(Double.random(in: 0...4) * seasonalMultiplier)
                return baseActivity
            }
        ),
        
        // Sparse but consistent pattern
        ChartItemViewModel(
            title: "Consistent Light Activity",
            type: .contribution,
            colorScheme: .teal,
            data: Array(0..<365).map { day in
                let probability = Double.random(in: 0...1)
                if probability < 0.3 {
                    return Int.random(in: 1...2)
                } else {
                    return 0
                }
            }
        )
    ]
} 
