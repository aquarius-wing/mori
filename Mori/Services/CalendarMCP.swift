import Foundation
import EventKit

class CalendarMCP: ObservableObject {
    private let eventStore = EKEventStore()
    
    // MARK: - Tool Definition
    static func getToolDescription() -> String {
        return """
        Tool: read_calendar
        Description: If user ask about calendar or events, use this tool to read calendar events.
        Arguments:
        - fromDate: like 2024/01/31 (required)
        - toDate: like 2024/01/31 (required)
        """
    }
    
    // MARK: - Available Tools List
    static func getAvailableTools() -> [String] {
        return ["read_calendar"]
    }
    
    // MARK: - Calendar Access
    func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("❌ Calendar access error: \(error.localizedDescription)")
                }
                print("📅 Calendar access granted: \(granted)")
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Tool Functions
    func readCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        print("📅 Reading calendar with arguments: \(arguments)")
        
        // Parse arguments
        guard let startDateString = arguments["fromDate"] as? String,
              let endDateString = arguments["toDate"] as? String else {
            throw CalendarMCPError.invalidArguments("fromDate and toDate are required")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            throw CalendarMCPError.invalidDateFormat("Date format should be YYYY/MM/DD")
        }
        
        // Check calendar access
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw CalendarMCPError.accessDenied("Calendar access not granted")
        }
        
        // Create predicate for date range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Convert events to dictionary format
        let eventList = events.map { event in
            return [
                "title": event.title ?? "No Title",
                "start_time": ISO8601DateFormatter().string(from: event.startDate),
                "end_time": ISO8601DateFormatter().string(from: event.endDate),
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "is_all_day": event.isAllDay
            ]
        }
        
        print("📅 Found \(eventList.count) events")
        
        return [
            "success": true,
            "events": eventList,
            "count": eventList.count,
            "date_range": [
                "fromDate": startDateString,
                "toDate": endDateString
            ]
        ]
    }
}

// MARK: - Errors
enum CalendarMCPError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidDateFormat(String)
    case accessDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .invalidDateFormat(let message):
            return "Invalid date format: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        }
    }
} 