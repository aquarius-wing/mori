import Foundation
import PersonalSync
import GRDB

// MARK: - Game Data Models
struct GameActivityData: Codable {
    let date: Date
    let hours: Double
    
    init(date: Date, hours: Double) {
        self.date = date
        self.hours = hours
    }
}

// MARK: - Game Data Service
class GameDataService: ObservableObject {
    static let shared = GameDataService()
    
    @Published var gameActivities: [GameActivityData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var databasePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("CalendarSync.sqlite").path
    }
    
    private init() {
        loadGameData()
    }
    
    // Load game activity data from database
    func loadGameData() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let activities = try self.fetchGameActivities()

                // print json
                let json = try JSONEncoder().encode(activities)
                let jsonString = String(data: json, encoding: .utf8)
                print("🔍 Game Activities: \(jsonString)")
                
                DispatchQueue.main.async {
                    self.gameActivities = activities
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load game data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Fetch game activities from GRDB database
    private func fetchGameActivities() throws -> [GameActivityData] {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            throw GameDataError.databaseNotFound
        }
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        
        return try dbQueue.read { db in
            let sql = """
                SELECT 
                    DATE(startDate) AS event_date,
                    SUM((JULIANDAY(endDate) - JULIANDAY(startDate)) * 24) AS total_hours
                FROM calendar_events
                WHERE title LIKE '%🎮%'
                  AND endDate > startDate  -- 确保时长非负
                GROUP BY DATE(startDate)
                ORDER BY event_date ASC;
            """
            
            var activities: [GameActivityData] = []
            let rows = try Row.fetchAll(db, sql: sql)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for row in rows {
                if let dateString = row["event_date"] as String?,
                   let date = dateFormatter.date(from: dateString),
                   let hours = row["total_hours"] as Double? {
                    activities.append(GameActivityData(date: date, hours: hours))
                }
            }
            
            return activities
        }
    }
    
    // Get data for AxisContribution chart (last 365 days)
    func getContributionData() -> [Int: Double] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate
        
        var contributionData: [Int: Double] = [:]
        
        // Fill in all dates with 0 hours
        var currentDate = startDate
        while currentDate <= endDate {
            let timestamp = Int(calendar.startOfDay(for: currentDate).timeIntervalSince1970)
            contributionData[timestamp] = 0.0
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add actual game data
        for activity in gameActivities {
            let dateKey = calendar.startOfDay(for: activity.date)
            if dateKey >= startDate && dateKey <= endDate {
                let timestamp = Int(dateKey.timeIntervalSince1970)
                contributionData[timestamp] = activity.hours
            }
        }
        
        return contributionData
    }
    
    // Get summary statistics
    func getTotalGameHours() -> Double {
        return gameActivities.reduce(0) { $0 + $1.hours }
    }
    
    func getAverageHoursPerDay() -> Double {
        guard !gameActivities.isEmpty else { return 0 }
        return getTotalGameHours() / Double(gameActivities.count)
    }
    
    func getMaxHoursInDay() -> Double {
        return gameActivities.map { $0.hours }.max() ?? 0
    }
}

// MARK: - Errors
enum GameDataError: Error, LocalizedError {
    case databaseNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Calendar database not found. Please sync your calendar data first."
        case .invalidData:
            return "Invalid data format in database."
        }
    }
} 