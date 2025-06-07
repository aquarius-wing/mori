import Foundation
import EventKit

class CalendarMCP: ObservableObject {
    private let eventStore = EKEventStore()
    
    // MARK: - Tool Definition
    static func getToolDescription() -> String {
        return """
        Tool: read-calendar
        Description: If user ask about calendar or events, use this tool to read calendar events.
        Arguments:
        - startDate: like 2024/01/30 (required)
        - endDate: like 2024/01/31 (required)
        
        IMPORTANT: endDate is a left-closed, right-open interval [startDate, endDate). 
        This means if you want to query events for today only, endDate should be tomorrow.
        For example, to query events on 2024/01/30, use startDate: 2024/01/30 and endDate: 2024/01/31.
        To query events for a whole week from 2024/01/30 to 2024/02/05, use startDate: 2024/01/30 and endDate: 2024/02/06.
        
        Example:
        User: What is the event on 2024/01/30?
        Assistant: {
            "tool": "read-calendar",
            "arguments": {
                "startDate": "2024/01/30",
                "endDate": "2024/01/31"
            }
        }
        
        
        Tool: update-calendar
        Description: Create or update calendar events.
        Arguments:
        - title: Event title (required)
        - startDate: Start date like 2024/01/31 (required)
        - endDate: End date like 2024/01/31 (required)
        - startTime: Start time like 14:30 (optional, format HH:mm)
        - endTime: End time like 16:00 (optional, format HH:mm)
        - location: Event location (optional)
        - notes: Event notes (optional)
        - isAllDay: true/false for all day event (optional, default false)
        """
    }
    
    // MARK: - Available Tools List
    static func getAvailableTools() -> [String] {
        return ["read-calendar", "update-calendar"]
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
        guard let startDateString = arguments["startDate"] as? String,
              let endDateString = arguments["endDate"] as? String else {
            throw CalendarMCPError.invalidArguments("startDate and endDate are required")
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
                "startDate": startDateString,
                "endDate": endDateString
            ]
        ]
    }
    
    func updateCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        print("📅 Creating calendar event with arguments: \(arguments)")
        
        // Parse required arguments
        guard let title = arguments["title"] as? String,
              let startDateString = arguments["startDate"] as? String,
              let endDateString = arguments["endDate"] as? String else {
            throw CalendarMCPError.invalidArguments("title, startDate and endDate are required")
        }
        
        // Parse optional arguments
        let startTimeString = arguments["startTime"] as? String
        let endTimeString = arguments["endTime"] as? String
        let location = arguments["location"] as? String ?? ""
        let notes = arguments["notes"] as? String ?? ""
        let isAllDay = arguments["isAllDay"] as? Bool ?? false
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            throw CalendarMCPError.invalidDateFormat("Date format should be YYYY/MM/DD")
        }
        
        // Parse times if provided
        var finalStartDate = startDate
        var finalEndDate = endDate
        
        if let startTimeString = startTimeString, let endTimeString = endTimeString {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            guard let startTime = timeFormatter.date(from: startTimeString),
                  let endTime = timeFormatter.date(from: endTimeString) else {
                throw CalendarMCPError.invalidDateFormat("Time format should be HH:mm")
            }
            
            let calendar = Calendar.current
            let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            
            finalStartDate = calendar.date(bySettingHour: startTimeComponents.hour ?? 0,
                                         minute: startTimeComponents.minute ?? 0,
                                         second: 0,
                                         of: startDate) ?? startDate
            
            finalEndDate = calendar.date(bySettingHour: endTimeComponents.hour ?? 0,
                                       minute: endTimeComponents.minute ?? 0,
                                       second: 0,
                                       of: endDate) ?? endDate
        }
        
        // Check calendar access
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw CalendarMCPError.accessDenied("Calendar access not granted")
        }
        
        // Create new event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = finalStartDate
        event.endDate = finalEndDate
        event.location = location
        event.notes = notes
        event.isAllDay = isAllDay
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            print("📅 Event created successfully: \(title)")
            
            return [
                "success": true,
                "message": "Event created successfully",
                "event": [
                    "title": title,
                    "start_time": ISO8601DateFormatter().string(from: finalStartDate),
                    "end_time": ISO8601DateFormatter().string(from: finalEndDate),
                    "location": location,
                    "notes": notes,
                    "is_all_day": isAllDay
                ]
            ]
        } catch {
            print("❌ Failed to create event: \(error.localizedDescription)")
            throw CalendarMCPError.creationFailed("Failed to create event: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors
enum CalendarMCPError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidDateFormat(String)
    case accessDenied(String)
    case creationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .invalidDateFormat(let message):
            return "Invalid date format: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .creationFailed(let message):
            return "Creation failed: \(message)"
        }
    }
} 