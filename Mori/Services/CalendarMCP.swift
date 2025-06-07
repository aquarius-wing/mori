import Foundation
import EventKit

class CalendarMCP: ObservableObject {
    private let eventStore = EKEventStore()
    
    // MARK: - Tool Definition
    static func getToolDescription() -> String {
        return """
        Tool: read-calendar
        Description: If user ask about calendar or events or meeting or something maybe in Calendar, use this tool to read calendar events.
        Arguments:
        - startDate: like 2024-01-30T00:00:00Z (required)
        - endDate: like 2024-01-31T23:59:59Z (required)
        
        
        Tool: update-calendar
        Description: Create or update calendar events.
        Arguments:
        - id: Event id (required)
        - title: Event title (optional)
        - startDate: Start date like 2024-01-31T00:00:00Z (optional)
        - endDate: End date like 2024-01-31T23:59:59Z (optional)
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
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        guard let startDate = dateFormatter.date(from: startDateString),
              let endDate = dateFormatter.date(from: endDateString) else {
            throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
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
                "id": event.eventIdentifier ?? "",
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
        print("📅 Updating/Creating calendar event with arguments: \(arguments)")
        
        // Check calendar access first
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw CalendarMCPError.accessDenied("Calendar access not granted")
        }
        
        // Check if this is an update (id provided) or create new event
        if let eventId = arguments["id"] as? String, !eventId.isEmpty {
            // Update existing event
            guard let existingEvent = eventStore.event(withIdentifier: eventId) else {
                throw CalendarMCPError.eventNotFound("Event with id \(eventId) not found")
            }
            
            // Update fields if provided
            if let title = arguments["title"] as? String {
                existingEvent.title = title
            }
            
            if let location = arguments["location"] as? String {
                existingEvent.location = location
            }
            
            if let notes = arguments["notes"] as? String {
                existingEvent.notes = notes
            }
            
            if let isAllDay = arguments["isAllDay"] as? Bool {
                existingEvent.isAllDay = isAllDay
            }
            
            // Handle date/time updates
            guard let eventStartDate = existingEvent.startDate,
                  let eventEndDate = existingEvent.endDate else {
                throw CalendarMCPError.invalidArguments("Event has invalid dates")
            }
            
            var finalStartDate = eventStartDate
            var finalEndDate = eventEndDate
            
            if let startDateString = arguments["startDate"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                
                guard let startDate = dateFormatter.date(from: startDateString) else {
                    throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
                }
                finalStartDate = startDate
            }
            
            if let endDateString = arguments["endDate"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                
                guard let endDate = dateFormatter.date(from: endDateString) else {
                    throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
                }
                finalEndDate = endDate
            }
            
            // Handle time updates
            if let startTimeString = arguments["startTime"] as? String,
               let endTimeString = arguments["endTime"] as? String {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                
                guard let startTime = timeFormatter.date(from: startTimeString),
                      let endTime = timeFormatter.date(from: endTimeString) else {
                    throw CalendarMCPError.invalidDateFormat("Time format should be HH:mm")
                }
                
                let calendar = Calendar.current
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                
                if let newStartDate = calendar.date(bySettingHour: startTimeComponents.hour ?? 0,
                                                  minute: startTimeComponents.minute ?? 0,
                                                  second: 0,
                                                  of: finalStartDate) {
                    finalStartDate = newStartDate
                }
                
                if let newEndDate = calendar.date(bySettingHour: endTimeComponents.hour ?? 0,
                                                minute: endTimeComponents.minute ?? 0,
                                                second: 0,
                                                of: finalEndDate) {
                    finalEndDate = newEndDate
                }
            }
            
            existingEvent.startDate = finalStartDate
            existingEvent.endDate = finalEndDate
            
            // Save updated event
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                print("📅 Event updated successfully: \(existingEvent.title ?? "")")
                
                return [
                    "success": true,
                    "message": "Event updated successfully",
                    "event": [
                        "id": eventId,
                        "title": existingEvent.title ?? "",
                        "start_time": ISO8601DateFormatter().string(from: finalStartDate),
                        "end_time": ISO8601DateFormatter().string(from: finalEndDate),
                        "location": existingEvent.location ?? "",
                        "notes": existingEvent.notes ?? "",
                        "is_all_day": existingEvent.isAllDay
                    ]
                ]
            } catch {
                print("❌ Failed to update event: \(error.localizedDescription)")
                throw CalendarMCPError.updateFailed("Failed to update event: \(error.localizedDescription)")
            }
            
        } else {
            // Create new event (original functionality)
            guard let title = arguments["title"] as? String,
                  let startDateString = arguments["startDate"] as? String,
                  let endDateString = arguments["endDate"] as? String else {
                throw CalendarMCPError.invalidArguments("For new events: title, startDate and endDate are required")
            }
            
            // Parse optional arguments
            let startTimeString = arguments["startTime"] as? String
            let endTimeString = arguments["endTime"] as? String
            let location = arguments["location"] as? String ?? ""
            let notes = arguments["notes"] as? String ?? ""
            let isAllDay = arguments["isAllDay"] as? Bool ?? false
            
            // Parse dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            
            guard let startDate = dateFormatter.date(from: startDateString),
                  let endDate = dateFormatter.date(from: endDateString) else {
                throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
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
                
                if let newStartDate = calendar.date(bySettingHour: startTimeComponents.hour ?? 0,
                                                  minute: startTimeComponents.minute ?? 0,
                                                  second: 0,
                                                  of: startDate) {
                    finalStartDate = newStartDate
                }
                
                if let newEndDate = calendar.date(bySettingHour: endTimeComponents.hour ?? 0,
                                                minute: endTimeComponents.minute ?? 0,
                                                second: 0,
                                                of: endDate) {
                    finalEndDate = newEndDate
                }
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
                        "id": event.eventIdentifier ?? "",
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
}

// MARK: - Errors
enum CalendarMCPError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidDateFormat(String)
    case accessDenied(String)
    case creationFailed(String)
    case eventNotFound(String)
    case updateFailed(String)
    
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
        case .eventNotFound(let message):
            return "Event not found: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        }
    }
} 
