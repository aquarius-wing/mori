import Foundation
import SwiftUI

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
        }
    }
}

// Chart Item model
struct ChartItem: Identifiable {
    let id = UUID()
    let title: String
    let type: ChartType
    let colorScheme: ChartColorScheme
    let data: [Int] // Sample data for demonstration
    
    // Sample data
    static let sampleData: [ChartItem] = [
        ChartItem(title: "Activity Overview", type: .contribution, colorScheme: .blue, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Green Theme", type: .contribution, colorScheme: .green, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Amber Style", type: .contribution, colorScheme: .amber, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Rose Theme", type: .contribution, colorScheme: .rose, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Purple Scheme", type: .contribution, colorScheme: .purple, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Orange Theme", type: .contribution, colorScheme: .orange, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Teal Style", type: .contribution, colorScheme: .teal, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Slate Theme", type: .contribution, colorScheme: .slate, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Red Scheme", type: .contribution, colorScheme: .red, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) }),
        ChartItem(title: "Indigo Style", type: .contribution, colorScheme: .indigo, data: Array(repeating: 0, count: 365).enumerated().map { index, _ in Int.random(in: 0...4) })
    ]
} 