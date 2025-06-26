import Foundation
import EventKit
import SwiftUI

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



struct CalendarAddResponse: Codable {
    let success: Bool
    let message: String
    let event: CalendarEvent
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
        - id: Event id (required, must get id from read-calendar tool)
        - title: Event title (optional)
        - startDate: Start date like \(startString) (optional)
        - endDate: End date like \(endString) (optional)
        - location: Event location (optional)
        - notes: Event notes (optional)
        - isAllDay: true/false for all day event (optional, default false)
        
        Tool: remove-calendar
        Description: Delete a calendar event.
        Arguments:
        - id: Event id (required, must get id from read-calendar tool)
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
            
            let response = CalendarAddResponse(
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

// MARK: - SwiftUI View Extensions
extension CalendarMCP {
    
    // MARK: - Calendar Read Result View
    static func createReadResultView(
        step: WorkflowStep,
        showingCalendarDetail: Binding<Bool>,
        showingCalendarConfirmation: Binding<Bool>,
        eventToOpen: Binding<CalendarEvent?>
    ) -> some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let calendarResponse = try? JSONDecoder().decode(
                   CalendarReadResponse.self,
                   from: jsonData
               )
            {
                VStack(spacing: 16) {
                    // Header with open calendar button
                    HStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Found \(calendarResponse.count) events")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(formatDateRange(from: calendarResponse.dateRange))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Events list - show at most 3 events
                    if !calendarResponse.events.isEmpty {
                        VStack(spacing: 12) {
                            // Display first 3 events
                            ForEach(Array(calendarResponse.events.prefix(3).enumerated()), id: \.offset) { index, event in
                                CalendarEventDetailRowWithButton(event: event) {
                                    Button(action: {
                                        eventToOpen.wrappedValue = event
                                        showingCalendarConfirmation.wrappedValue = true
                                    }) {
                                        Image(systemName: "calendar")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .padding(8)
                                    }
                                }
                            }
                            
                            // Show "more" button if there are more than 3 events
                            if calendarResponse.events.count > 3 {
                                Button(action: {
                                    showingCalendarDetail.wrappedValue = true
                                }) {
                                    HStack {
                                        Text("Show \(calendarResponse.events.count - 3) more events")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                            Text("No events found")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.2))
                )
                .padding(.horizontal, 20)
                .alert("Open in Calendar", isPresented: showingCalendarConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open") {
                        if let event = eventToOpen.wrappedValue {
                            openEventInCalendar(event)
                        }
                    }
                } message: {
                    if let event = eventToOpen.wrappedValue {
                        Text("Do you want to open '\(event.title)' in the Calendar app?")
                    }
                }
                .sheet(isPresented: showingCalendarDetail) {
                    CalendarEventsDetailView(
                        title: "Read Calendar",
                        subtitle: formatDateRange(from: calendarResponse.dateRange),
                        events: calendarResponse.events
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Calendar Update Result View
    static func createUpdateResultView(
        step: WorkflowStep,
        showingCalendarConfirmation: Binding<Bool>,
        eventToOpen: Binding<CalendarEvent?>
    ) -> some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let updateResponse = try? JSONDecoder().decode(
                   CalendarUpdateResponse.self,
                   from: jsonData
               )
            {
                CalendarEventDetailRowWithButton(event: updateResponse.event) {
                    Button(action: {
                        eventToOpen.wrappedValue = updateResponse.event
                        showingCalendarConfirmation.wrappedValue = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            (updateResponse.success ? Color.green : Color.red)
                                .opacity(0.2)
                        )
                )
                .padding(.horizontal, 20)
                .alert("Open in Calendar", isPresented: showingCalendarConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open") {
                        if let event = eventToOpen.wrappedValue {
                            openEventInCalendar(event)
                        }
                    }
                } message: {
                    if let event = eventToOpen.wrappedValue {
                        Text("Do you want to open '\(event.title)' in the Calendar app?")
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Calendar Add Result View
    static func createAddResultView(
        step: WorkflowStep,
        showingCalendarConfirmation: Binding<Bool>,
        eventToOpen: Binding<CalendarEvent?>
    ) -> some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let addResponse = try? JSONDecoder().decode(
                   CalendarAddResponse.self,
                   from: jsonData
               )
            {
                CalendarEventDetailRowWithButton(event: addResponse.event) {
                    Button(action: {
                        eventToOpen.wrappedValue = addResponse.event
                        showingCalendarConfirmation.wrappedValue = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            (addResponse.success ? Color.green : Color.red)
                                .opacity(0.2)
                        )
                )
                .padding(.horizontal, 20)
                .alert("Open in Calendar", isPresented: showingCalendarConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open") {
                        if let event = eventToOpen.wrappedValue {
                            openEventInCalendar(event)
                        }
                    }
                } message: {
                    if let event = eventToOpen.wrappedValue {
                        Text("Do you want to open '\(event.title)' in the Calendar app?")
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Calendar Remove Result View
    static func createRemoveResultView(
        step: WorkflowStep
    ) -> some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let deleteResponse = try? JSONDecoder().decode(
                   CalendarDeleteResponse.self,
                   from: jsonData
               )
            {
                VStack(spacing: 16) {
                    // Header with success/failure indicator
                    HStack(spacing: 16) {
                        Image(systemName: deleteResponse.success ? "trash.circle" : "xmark.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(deleteResponse.success ? "Event Deleted Successfully" : "Failed to Delete Event")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(deleteResponse.message)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        if deleteResponse.success {
                            Button(action: {
                                openCalendarApp()
                            }) {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            (deleteResponse.success ? Color.orange : Color.red)
                                .opacity(0.2)
                        )
                )
                .padding(.horizontal, 20)
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Helper Functions
    private static func openCalendarApp() {
        let schemes = ["calshow://", "x-apple-calendar://"]
        
        for scheme in schemes {
            print("🔍 Trying to open calendar with scheme: \(scheme)")
            guard let url = URL(string: scheme) else { 
                print("❌ Invalid URL scheme: \(scheme)")
                continue 
            }
            
            if UIApplication.shared.canOpenURL(url) {
                print("✅ Opening calendar app with: \(scheme)")
                UIApplication.shared.open(url)
                return
            } else {
                print("❌ Cannot open calendar with scheme: \(scheme)")
            }
        }
        
        print("❌ No calendar URL schemes worked")
    }
    
    private static func openEventInCalendar(_ event: CalendarEvent) {
        // Debug logging
        print("🔍 Trying to open event: \(event.title)")
        print("🔍 Event ID: '\(event.id)'")
        print("🔍 Start Date: \(event.startDate)")
        
        // Use event ID to open specific event in calendar
        if !event.id.isEmpty {
            // Use the correct iOS calendar URL scheme format
            let eventIdentifier = event.id.replacingOccurrences(of: ":", with: "/")
            let urlString = "x-apple-calevent://\(eventIdentifier)"
            
            print("🔍 Trying URL: \(urlString)")
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    print("✅ Opening URL: \(urlString)")
                    UIApplication.shared.open(url)
                    return
                } else {
                    print("❌ Cannot open URL: \(urlString)")
                }
            } else {
                print("❌ Invalid URL: \(urlString)")
            }
        } else {
            print("❌ Event ID is empty")
        }
        
        // Try to parse the date for calendar URL as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        if let startDate = isoFormatter.date(from: event.startDate) {
            // Format date for calendar URL
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
            if let year = dateComponents.year, let month = dateComponents.month, let day = dateComponents.day {
                let dateString = String(format: "%04d%02d%02d", year, month, day)
                let dateUrlString = "calshow://\(dateString)"
                print("🔍 Trying date URL: \(dateUrlString)")
                
                if let dateUrl = URL(string: dateUrlString) {
                    if UIApplication.shared.canOpenURL(dateUrl) {
                        print("✅ Opening date URL: \(dateUrlString)")
                        UIApplication.shared.open(dateUrl)
                        return
                    }
                }
            }
        }
        
        // Final fallback to opening calendar app
        print("🔍 Falling back to opening calendar app")
        openCalendarApp()
    }
    
    // MARK: - Date Range Formatting
    private static func formatDateRange(from dateRange: DateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current
        
        // Try to parse start date
        let startDate: Date?
        let endDate: Date?
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        // Try ISO format first, then fallback to manual format
        if let date = isoFormatter.date(from: dateRange.startDate) {
            startDate = date
        } else {
            startDate = formatter.date(from: dateRange.startDate)
        }
        
        if let date = isoFormatter.date(from: dateRange.endDate) {
            endDate = date
        } else {
            endDate = formatter.date(from: dateRange.endDate)
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.timeZone = TimeZone.current
        
        if let start = startDate, let end = endDate {
            // Check if it's the same day
            let calendar = Calendar.current
            if calendar.isDate(start, inSameDayAs: end) {
                displayFormatter.dateFormat = "MMM d, yyyy"
                let dateStr = displayFormatter.string(from: start)
                
                // Add time range if not a full day
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = TimeZone.current
                
                let startTime = timeFormatter.string(from: start)
                let endTime = timeFormatter.string(from: end)
                
                // Check if it's likely a full day (00:00-23:59 or similar)
                if startTime == "00:00" && (endTime == "23:59" || endTime == "00:00") {
                    return dateStr
                } else {
                    return "\(dateStr) \(startTime)-\(endTime)"
                }
            } else {
                displayFormatter.dateFormat = "MMM d"
                let startStr = displayFormatter.string(from: start)
                let endStr = displayFormatter.string(from: end)
                
                // Add year if different
                let yearFormatter = DateFormatter()
                yearFormatter.dateFormat = "yyyy"
                let startYear = yearFormatter.string(from: start)
                let endYear = yearFormatter.string(from: end)
                
                if startYear == endYear {
                    return "\(startStr) - \(endStr), \(startYear)"
                } else {
                    return "\(startStr), \(startYear) - \(endStr), \(endYear)"
                }
            }
        }
        
        return "Date range: \(dateRange.startDate) - \(dateRange.endDate)"
    }
}
