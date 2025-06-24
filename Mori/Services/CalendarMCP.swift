import Foundation
import EventKit

// MARK: - Calendar Response Types
struct CalendarReadResponse: Codable {
    let success: Bool
    let events: [CalendarEvent]
    let count: Int
    let dateRange: DateRange
    
    enum CodingKeys: String, CodingKey {
        case success
        case events
        case count
        case dateRange = "date_range"
    }
}

struct CalendarEvent: Codable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let location: String
    let notes: String
    let isAllDay: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case location
        case notes
        case isAllDay = "is_all_day"
    }
}

struct DateRange: Codable {
    let startDate: String
    let endDate: String
}

struct CalendarUpdateResponse: Codable {
    let success: Bool
    let message: String
    let event: CalendarEvent
}

struct CalendarDeleteResponse: Codable {
    let success: Bool
    let message: String
    let eventId: String
}

class CalendarMCP: ObservableObject {
    private let eventStore = EKEventStore()
    
    // MARK: - Tool Definition
    static func getToolDescription() -> String {
        // current time zone as +08:00
        let base = Date()                // e.g. today; could come from DatePicker, server, etc.
        let calendar = Calendar.current  // or Calendar(identifier: .gregorian)

        // 1. Build the two boundary Date values
        var start = calendar.startOfDay(for: base)          // 00:00:00 local
        var components = DateComponents(second: 86_399)     // 23 h 59 m 59 s  =  24h-1s
        let end = calendar.date(byAdding: components, to: start)!  // 23:59:59
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        return """
        Tool: read-calendar
        Description: If user ask about calendar or events or meeting or something maybe in Calendar, use this tool to read calendar events.
        Arguments:
        - startDate: like \(startString) (required)
        - endDate: like \(endString) (required)
        
        Tool: add-calendar
        Description: Create a new calendar event.
        Arguments:
        - title: Event title (required)
        - startDate: Start date like \(startString) (required)
        - endDate: End date like \(endString) (required)
        - location: Event location (optional)
        - notes: Event notes (optional)
        - isAllDay: true/false for all day event (optional, default false)
        
        Tool: update-calendar
        Description: Update an existing calendar event.
        Arguments:
        - id: Event id (required)
        - title: Event title (optional)
        - startDate: Start date like \(startString) (optional)
        - endDate: End date like \(endString) (optional)
        - location: Event location (optional)
        - notes: Event notes (optional)
        - isAllDay: true/false for all day event (optional, default false)
        
        Tool: remove-calendar
        Description: Delete a calendar event.
        Arguments:
        - id: Event id (required)
        """
    }
    
    // MARK: - Available Tools List
    static func getAvailableTools() -> [String] {
        return ["read-calendar", "add-calendar", "update-calendar", "remove-calendar"]
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
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        guard let startDate = isoFormatter.date(from: startDateString),
              let endDate = isoFormatter.date(from: endDateString) else {
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
        let outputFormatter = ISO8601DateFormatter()
        outputFormatter.timeZone = TimeZone.current
        
        let eventList = events.map { event in
            return [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "No Title",
                "start_date": outputFormatter.string(from: event.startDate),
                "end_date": outputFormatter.string(from: event.endDate),
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "is_all_day": event.isAllDay
            ]
        }
        
        print("📅 Found \(eventList.count) events")
        
        let response = CalendarReadResponse(
            success: true,
            events: eventList.map { eventDict in
                CalendarEvent(
                    id: eventDict["id"] as? String ?? "",
                    title: eventDict["title"] as? String ?? "",
                    startDate: eventDict["start_date"] as? String ?? "",
                    endDate: eventDict["end_date"] as? String ?? "",
                    location: eventDict["location"] as? String ?? "",
                    notes: eventDict["notes"] as? String ?? "",
                    isAllDay: eventDict["is_all_day"] as? Bool ?? false
                )
            },
            count: eventList.count,
            dateRange: DateRange(startDate: startDateString, endDate: endDateString)
        )
        
        // Convert to dictionary for compatibility
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        
        return dictionary
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
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.timeZone = TimeZone.current
                
                guard let startDate = isoFormatter.date(from: startDateString) else {
                    throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
                }
                finalStartDate = startDate
            }
            
            if let endDateString = arguments["endDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.timeZone = TimeZone.current
                
                guard let endDate = isoFormatter.date(from: endDateString) else {
                    throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
                }
                finalEndDate = endDate
            }
            

            
            existingEvent.startDate = finalStartDate
            existingEvent.endDate = finalEndDate
            
            // Save updated event
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                print("📅 Event updated successfully: \(existingEvent.title ?? "")")
                
                let outputFormatter = ISO8601DateFormatter()
                outputFormatter.timeZone = TimeZone.current
                
                let event = CalendarEvent(
                    id: eventId,
                    title: existingEvent.title ?? "",
                    startDate: outputFormatter.string(from: finalStartDate),
                    endDate: outputFormatter.string(from: finalEndDate),
                    location: existingEvent.location ?? "",
                    notes: existingEvent.notes ?? "",
                    isAllDay: existingEvent.isAllDay
                )
                
                let response = CalendarUpdateResponse(
                    success: true,
                    message: "Event updated successfully",
                    event: event
                )
                
                // Convert to dictionary for compatibility
                let encoder = JSONEncoder()
                let data = try encoder.encode(response)
                let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                
                return dictionary
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
            let location = arguments["location"] as? String ?? ""
            let notes = arguments["notes"] as? String ?? ""
            let isAllDay = arguments["isAllDay"] as? Bool ?? false
            
            // Parse dates
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.timeZone = TimeZone.current
            
            guard let startDate = isoFormatter.date(from: startDateString),
                  let endDate = isoFormatter.date(from: endDateString) else {
                throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
            }
            
            // Use the parsed dates directly
            let finalStartDate = startDate
            let finalEndDate = endDate
            
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
                
                let outputFormatter = ISO8601DateFormatter()
                outputFormatter.timeZone = TimeZone.current
                
                let calendarEvent = CalendarEvent(
                    id: event.eventIdentifier ?? "",
                    title: title,
                    startDate: outputFormatter.string(from: finalStartDate),
                    endDate: outputFormatter.string(from: finalEndDate),
                    location: location,
                    notes: notes,
                    isAllDay: isAllDay
                )
                
                let response = CalendarUpdateResponse(
                    success: true,
                    message: "Event created successfully",
                    event: calendarEvent
                )
                
                // Convert to dictionary for compatibility
                let encoder = JSONEncoder()
                let data = try encoder.encode(response)
                let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                
                return dictionary
            } catch {
                print("❌ Failed to create event: \(error.localizedDescription)")
                throw CalendarMCPError.creationFailed("Failed to create event: \(error.localizedDescription)")
            }
        }
    }
    
    func addCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        print("📅 Creating new calendar event with arguments: \(arguments)")
        
        // Check calendar access first
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw CalendarMCPError.accessDenied("Calendar access not granted")
        }
        
        // Validate required arguments
        guard let title = arguments["title"] as? String,
              let startDateString = arguments["startDate"] as? String,
              let endDateString = arguments["endDate"] as? String else {
            throw CalendarMCPError.invalidArguments("title, startDate and endDate are required")
        }
        
        // Parse optional arguments
        let location = arguments["location"] as? String ?? ""
        let notes = arguments["notes"] as? String ?? ""
        let isAllDay = arguments["isAllDay"] as? Bool ?? false
        
        // Parse dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        guard let startDate = isoFormatter.date(from: startDateString),
              let endDate = isoFormatter.date(from: endDateString) else {
            throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
        }
        
        // Create new event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.isAllDay = isAllDay
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            print("📅 Event created successfully: \(title)")
            
            let outputFormatter = ISO8601DateFormatter()
            outputFormatter.timeZone = TimeZone.current
            
            let calendarEvent = CalendarEvent(
                id: event.eventIdentifier ?? "",
                title: title,
                startDate: outputFormatter.string(from: startDate),
                endDate: outputFormatter.string(from: endDate),
                location: location,
                notes: notes,
                isAllDay: isAllDay
            )
            
            let response = CalendarUpdateResponse(
                success: true,
                message: "Event created successfully",
                event: calendarEvent
            )
            
            // Convert to dictionary for compatibility
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            
            return dictionary
        } catch {
            print("❌ Failed to create event: \(error.localizedDescription)")
            throw CalendarMCPError.creationFailed("Failed to create event: \(error.localizedDescription)")
        }
    }
    
    func removeCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        print("📅 Removing calendar event with arguments: \(arguments)")
        
        // Check calendar access first
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw CalendarMCPError.accessDenied("Calendar access not granted")
        }
        
        // Validate required arguments
        guard let eventId = arguments["id"] as? String, !eventId.isEmpty else {
            throw CalendarMCPError.invalidArguments("Event id is required")
        }
        
        // Find the event
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarMCPError.eventNotFound("Event with id \(eventId) not found")
        }
        
        // Save event title for response
        let eventTitle = event.title ?? "Untitled Event"
        
        // Delete event
        do {
            try eventStore.remove(event, span: .thisEvent)
            print("📅 Event deleted successfully: \(eventTitle)")
            
            let response = CalendarDeleteResponse(
                success: true,
                message: "Event '\(eventTitle)' deleted successfully",
                eventId: eventId
            )
            
            // Convert to dictionary for compatibility
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            
            return dictionary
        } catch {
            print("❌ Failed to delete event: \(error.localizedDescription)")
            throw CalendarMCPError.deletionFailed("Failed to delete event: \(error.localizedDescription)")
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
    case deletionFailed(String)
    
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
        case .deletionFailed(let message):
            return "Deletion failed: \(message)"
        }
    }
} 
