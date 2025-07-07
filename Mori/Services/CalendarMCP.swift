import Foundation
import EventKit
import SwiftUI
import PersonalSync

// MARK: - Calendar Settings Manager
class CalendarSettings: ObservableObject {
    static let shared = CalendarSettings()
    
    @Published var enabledCalendarIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIds), forKey: "enabledCalendarIds")
        }
    }
    
    @Published var defaultCalendarId: String? {
        didSet {
            UserDefaults.standard.set(defaultCalendarId, forKey: "defaultCalendarId")
        }
    }
    
    private init() {
        // Load enabled calendar IDs, default to all calendars if none saved
        if let savedIds = UserDefaults.standard.array(forKey: "enabledCalendarIds") as? [String] {
            self.enabledCalendarIds = Set(savedIds)
        } else {
            self.enabledCalendarIds = Set()
        }
        
        // Load default calendar ID
        self.defaultCalendarId = UserDefaults.standard.string(forKey: "defaultCalendarId")
    }
    
    func isCalendarEnabled(_ calendarId: String) -> Bool {
        // If no calendars are specifically enabled, treat all as enabled
        if enabledCalendarIds.isEmpty {
            return true
        }
        return enabledCalendarIds.contains(calendarId)
    }
    
    func enableCalendar(_ calendarId: String) {
        enabledCalendarIds.insert(calendarId)
    }
    
    func disableCalendar(_ calendarId: String) {
        enabledCalendarIds.remove(calendarId)
    }
    
    func toggleCalendar(_ calendarId: String) {
        if enabledCalendarIds.contains(calendarId) {
            enabledCalendarIds.remove(calendarId)
        } else {
            enabledCalendarIds.insert(calendarId)
        }
    }
    
    func initializeWithAllCalendars(_ calendars: [CalendarInfo]) {
        // Only initialize if no calendars are currently saved
        if enabledCalendarIds.isEmpty && UserDefaults.standard.array(forKey: "enabledCalendarIds") == nil {
            enabledCalendarIds = Set(calendars.map { $0.id })
        }
        
        // Set default calendar if none is set
        if defaultCalendarId == nil, let firstWritableCalendar = calendars.first(where: { $0.allowsContentModifications }) {
            defaultCalendarId = firstWritableCalendar.id
        }
    }
}

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
    let calendarId: String
    let calendarTitle: String
    let alarms: [CalendarAlarm]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case location
        case notes
        case isAllDay = "is_all_day"
        case calendarId = "calendar_id"
        case calendarTitle = "calendar_title"
        case alarms
    }
}

struct CalendarAlarm: Codable {
    let relativeOffset: Double? // Minutes before event (negative value)
    let absoluteDate: String?   // Absolute date for alarm
    
    enum CodingKeys: String, CodingKey {
        case relativeOffset = "relative_offset"
        case absoluteDate = "absolute_date"
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

struct CalendarInfo: Codable {
    let id: String
    let title: String
    let type: String
    let allowsContentModifications: Bool
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case allowsContentModifications = "allows_content_modifications"
        case color
    }
}

struct CalendarListResponse: Codable {
    let success: Bool
    let calendars: [CalendarInfo]
    let count: Int
}

class CalendarMCP: ObservableObject {
    private lazy var eventStore: EKEventStore = {
        return EKEventStore()
    }()
    
    private lazy var calendarSync: PersonalSync.CalendarSync? = {
        do {
            return try PersonalSync.CalendarSync()
        } catch {
            print("❌ Failed to initialize PersonalSync.CalendarSync: \(error.localizedDescription)")
            return nil
        }
    }()
    
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
        
        // Get calendar settings
        let calendarSettings = CalendarSettings.shared
        let availableCalendarsInfo = getAvailableCalendarsInfo()
        let enabledCalendarsInfo = availableCalendarsInfo.filter { calendarSettings.isCalendarEnabled($0.id) }
        let defaultCalendarInfo = availableCalendarsInfo.first { $0.id == calendarSettings.defaultCalendarId }
        
        var calendarInfoText = ""
        if !enabledCalendarsInfo.isEmpty {
            calendarInfoText += "\n\nAvailable Calendars (user has enabled these calendars for reading events):\n"
            for cal in enabledCalendarsInfo {
                let isDefault = cal.id == calendarSettings.defaultCalendarId
                calendarInfoText += "- \(cal.title) (\(cal.type))\(isDefault ? " [Default]" : ""): ID \(cal.id)\n"
            }
        }
        
        if let defaultCal = defaultCalendarInfo {
            calendarInfoText += "\nDefault Calendar for new events: \(defaultCal.title) (ID: \(defaultCal.id))\n"
        }
        
        return """
        Tool: read-calendar
        Description: If user ask about calendar or events or meeting or something maybe in Calendar, use this tool to read calendar events.
        Arguments:
        - startDate: like \(startString) (required)
        - endDate: like \(endString) (required)
        - keyword: Keyword to search for events (optional)
        - calendarId: Specific calendar ID to read from (optional, if not provided will read from user's enabled calendars)
        
        Tool: add-calendar
        Description: Create a new calendar event.
        Arguments:
        - title: Event title (required)
        - startDate: Start date like \(startString) (required)
        - endDate: End date like \(endString) (required)
        - location: Event location (optional)
        - notes: Event notes (optional)
        - isAllDay: true/false for all day event (optional, default false)
        - calendarId: Calendar ID to save the event to (optional, According to the event title and notes to match the corresponding calendar name, select the calendar ID that best fits as the value here.)
        - alarms: Array of alarm objects (optional). Each alarm can have:
          - relativeOffset: Minutes before/after event (e.g., -15 for 15 minutes before, 0 for event start time)
          - absoluteDate: Absolute date for alarm like \(startString)
          Example: [{"relativeOffset": -15}, {"relativeOffset": 0}]
        
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
        - calendarId: Calendar ID to move the event to (optional, According to the event title and notes to match the corresponding calendar name, select the calendar ID that best fits as the value here.)
        - alarms: Array of alarm objects (optional, will keep existing alarms if not provided). Each alarm can have:
          - relativeOffset: Minutes before/after event (e.g., -15 for 15 minutes before, 0 for event start time)
          - absoluteDate: Absolute date for alarm like \(startString)
          Example: [{"relativeOffset": -15}, {"relativeOffset": 0}]
        
        Tool: remove-calendar
        Description: Delete a calendar event.
        Arguments:
        - id: Event id (required, must get id from read-calendar tool)
        \(calendarInfoText)
        """
    }
    
    // MARK: - Available Tools List
    static func getAvailableTools() -> [String] {
        return ["read-calendar", "add-calendar", "update-calendar", "remove-calendar"]
    }
    
    // MARK: - Calendar Access
    func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                self.eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        print("❌ Calendar access error: \(error.localizedDescription)")
                    }
                    print("📅 Calendar access granted: \(granted)")
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func createAlarms(from alarmsData: Any?, useDefaultAlarm: Bool = true) -> [EKAlarm] {
        // If no alarms data provided and we should use default, create event start time alarm
        if alarmsData == nil && useDefaultAlarm {
            let defaultAlarm = EKAlarm()
            defaultAlarm.relativeOffset = 0 // At event start time
            return [defaultAlarm]
        }
        
        guard let alarmsArray = alarmsData as? [[String: Any]] else {
            return []
        }
        
        var ekAlarms: [EKAlarm] = []
        
        for alarmDict in alarmsArray {
            let alarm = EKAlarm()
            
            // Handle relative offset (in minutes, convert to seconds)
            if let relativeOffset = alarmDict["relativeOffset"] as? Double {
                alarm.relativeOffset = relativeOffset * 60.0 // Convert minutes to seconds
                ekAlarms.append(alarm)
            }
            // Handle absolute date
            else if let absoluteDateString = alarmDict["absoluteDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.timeZone = TimeZone.current
                
                if let absoluteDate = isoFormatter.date(from: absoluteDateString) {
                    alarm.absoluteDate = absoluteDate
                    ekAlarms.append(alarm)
                }
            }
        }
        
        return ekAlarms
    }
    
    // MARK: - Calendar Information
    static func getAvailableCalendarsInfo() -> [CalendarInfo] {
        // Ensure we're on main thread for EventKit operations
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return getAvailableCalendarsInfo()
            }
        }
        
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event)
        
        return calendars.map { calendar in
            // Get calendar type string
            let typeString: String
            switch calendar.type {
            case .local:
                typeString = "local"
            case .calDAV:
                typeString = "caldav"
            case .exchange:
                typeString = "exchange"
            case .subscription:
                typeString = "subscription"
            case .birthday:
                typeString = "birthday"
            @unknown default:
                typeString = "unknown"
            }
            
            // Get color hex string
            let colorHex: String?
            if let cgColor = calendar.cgColor {
                let color = UIColor(cgColor: cgColor)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                colorHex = String(format: "#%02X%02X%02X", 
                                Int(red * 255), 
                                Int(green * 255), 
                                Int(blue * 255))
            } else {
                colorHex = nil
            }
            
            return CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                type: typeString,
                allowsContentModifications: calendar.allowsContentModifications,
                color: colorHex
            )
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
        
        let calendarId = arguments["calendarId"] as? String
        let keyword = arguments["keyword"] as? String ?? ""
        
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
        
        // Use PersonalSync CalendarSync for reading events
        guard let calendarSync = calendarSync else {
            throw CalendarMCPError.accessDenied("PersonalSync CalendarSync not available")
        }
        
        // Prepare calendar identifiers list
        var calendarIdentifierList: [String]?
        if let calendarId = calendarId {
            // Use specific calendar
            calendarIdentifierList = [calendarId]
            print("📅 Reading from specific calendar: \(calendarId)")
        } else {
            // Read from user's enabled calendars
            let calendarSettings = CalendarSettings.shared
            let enabledCalendarIds = Array(calendarSettings.enabledCalendarIds)
            calendarIdentifierList = enabledCalendarIds.isEmpty ? nil : enabledCalendarIds
            print("📅 Reading from \(enabledCalendarIds.count) enabled calendars")
        }
        
        // Use PersonalSync searchEvents method
        let personalSyncEvents: [PersonalSync.CalendarEvent]
        do {
            personalSyncEvents = try calendarSync.searchEvents(
                keyword: keyword,
                from: startDate,
                to: endDate,
                calendarIdentifierList: calendarIdentifierList
            )
            if !keyword.isEmpty {
                print("📅 Searched with keyword: '\(keyword)'")
            }
        } catch {
            print("❌ PersonalSync searchEvents failed: \(error.localizedDescription)")
            throw CalendarMCPError.accessDenied("Failed to search events: \(error.localizedDescription)")
        }
        
        // Convert PersonalSync events to dictionary format
        let outputFormatter = ISO8601DateFormatter()
        outputFormatter.timeZone = TimeZone.current
        
        let eventList = personalSyncEvents.map { event in
            // Convert PersonalSync event to local format using extension
            let localEvent = event.toLocalCalendarEvent()
            
            return [
                "id": localEvent.id,
                "title": localEvent.title,
                "start_date": localEvent.startDate,
                "end_date": localEvent.endDate,
                "location": localEvent.location,
                "notes": localEvent.notes,
                "is_all_day": localEvent.isAllDay,
                "calendar_id": localEvent.calendarId,
                "calendar_title": localEvent.calendarTitle,
                "alarms": localEvent.alarms.map { alarm in
                    var alarmDict: [String: Any] = [:]
                    if let relativeOffset = alarm.relativeOffset {
                        alarmDict["relative_offset"] = relativeOffset
                    }
                    if let absoluteDate = alarm.absoluteDate {
                        alarmDict["absolute_date"] = absoluteDate
                    }
                    return alarmDict
                }
            ]
        }
        
        if !keyword.isEmpty {
            print("📅 Found \(eventList.count) events matching keyword '\(keyword)'")
        } else {
            print("📅 Found \(eventList.count) events")
        }
        
        let response = CalendarReadResponse(
            success: true,
            events: eventList.map { eventDict in
                let alarmsArray = eventDict["alarms"] as? [[String: Any]] ?? []
                let calendarAlarms = alarmsArray.map { alarmDict in
                    CalendarAlarm(
                        relativeOffset: alarmDict["relative_offset"] as? Double,
                        absoluteDate: alarmDict["absolute_date"] as? String
                    )
                }
                
                return CalendarEvent(
                    id: eventDict["id"] as? String ?? "",
                    title: eventDict["title"] as? String ?? "",
                    startDate: eventDict["start_date"] as? String ?? "",
                    endDate: eventDict["end_date"] as? String ?? "",
                    location: eventDict["location"] as? String ?? "",
                    notes: eventDict["notes"] as? String ?? "",
                    isAllDay: eventDict["is_all_day"] as? Bool ?? false,
                    calendarId: eventDict["calendar_id"] as? String ?? "",
                    calendarTitle: eventDict["calendar_title"] as? String ?? "",
                    alarms: calendarAlarms
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
            
            // Handle alarms updates
            if arguments["alarms"] != nil {
                existingEvent.alarms = createAlarms(from: arguments["alarms"], useDefaultAlarm: false)
            }
            
            // Handle calendar change
            if let calendarId = arguments["calendarId"] as? String {
                let allCalendars = eventStore.calendars(for: .event)
                guard let targetCalendar = allCalendars.first(where: { $0.calendarIdentifier == calendarId }) else {
                    throw CalendarMCPError.invalidArguments("Calendar with ID '\(calendarId)' not found")
                }
                guard targetCalendar.allowsContentModifications else {
                    throw CalendarMCPError.invalidArguments("Calendar '\(targetCalendar.title)' does not allow modifications")
                }
                existingEvent.calendar = targetCalendar
                print("📅 Moving event to calendar: \(targetCalendar.title)")
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
                
                // Convert EKAlarms to CalendarAlarm format
                let calendarAlarms = existingEvent.alarms?.map { ekAlarm in
                    CalendarAlarm(
                        relativeOffset: ekAlarm.relativeOffset / 60.0, // Convert seconds to minutes
                        absoluteDate: ekAlarm.absoluteDate != nil ? outputFormatter.string(from: ekAlarm.absoluteDate!) : nil
                    )
                } ?? []
                
                let event = CalendarEvent(
                    id: eventId,
                    title: existingEvent.title ?? "",
                    startDate: outputFormatter.string(from: finalStartDate),
                    endDate: outputFormatter.string(from: finalEndDate),
                    location: existingEvent.location ?? "",
                    notes: existingEvent.notes ?? "",
                    isAllDay: existingEvent.isAllDay,
                    calendarId: existingEvent.calendar?.calendarIdentifier ?? "",
                    calendarTitle: existingEvent.calendar?.title ?? "",
                    alarms: calendarAlarms
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
            let calendarId = arguments["calendarId"] as? String
            let alarms = createAlarms(from: arguments["alarms"])
            
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
            
            // Get target calendar
            let targetCalendar: EKCalendar
            if let calendarId = calendarId {
                let allCalendars = eventStore.calendars(for: .event)
                guard let specificCalendar = allCalendars.first(where: { $0.calendarIdentifier == calendarId }) else {
                    throw CalendarMCPError.invalidArguments("Calendar with ID '\(calendarId)' not found")
                }
                guard specificCalendar.allowsContentModifications else {
                    throw CalendarMCPError.invalidArguments("Calendar '\(specificCalendar.title)' does not allow modifications")
                }
                targetCalendar = specificCalendar
                print("📅 Using specific calendar: \(targetCalendar.title)")
            } else {
                // Use user's default calendar setting
                let calendarSettings = CalendarSettings.shared
                let allCalendars = eventStore.calendars(for: .event)
                
                if let defaultCalendarId = calendarSettings.defaultCalendarId,
                   let userDefaultCalendar = allCalendars.first(where: { $0.calendarIdentifier == defaultCalendarId }) {
                    targetCalendar = userDefaultCalendar
                    print("📅 Using user's default calendar: \(targetCalendar.title)")
                } else {
                    // Fallback to system default
                    guard let systemDefaultCalendar = eventStore.defaultCalendarForNewEvents else {
                        throw CalendarMCPError.invalidArguments("No default calendar available")
                    }
                    targetCalendar = systemDefaultCalendar
                    print("📅 Using system default calendar: \(targetCalendar.title)")
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
            event.alarms = alarms
            event.calendar = targetCalendar
            
            // Save event
            do {
                try eventStore.save(event, span: .thisEvent)
                print("📅 Event created successfully: \(title)")
                
                let outputFormatter = ISO8601DateFormatter()
                outputFormatter.timeZone = TimeZone.current
                
                // Convert EKAlarms to CalendarAlarm format
                let calendarAlarms = event.alarms?.map { ekAlarm in
                    CalendarAlarm(
                        relativeOffset: ekAlarm.relativeOffset / 60.0, // Convert seconds to minutes
                        absoluteDate: ekAlarm.absoluteDate != nil ? outputFormatter.string(from: ekAlarm.absoluteDate!) : nil
                    )
                } ?? []
                
                let calendarEvent = CalendarEvent(
                    id: event.eventIdentifier ?? "",
                    title: title,
                    startDate: outputFormatter.string(from: finalStartDate),
                    endDate: outputFormatter.string(from: finalEndDate),
                    location: location,
                    notes: notes,
                    isAllDay: isAllDay,
                    calendarId: event.calendar?.calendarIdentifier ?? "",
                    calendarTitle: event.calendar?.title ?? "",
                    alarms: calendarAlarms
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
        let calendarId = arguments["calendarId"] as? String
        let alarms = createAlarms(from: arguments["alarms"])
        
        // Parse dates
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        guard let startDate = isoFormatter.date(from: startDateString),
              let endDate = isoFormatter.date(from: endDateString) else {
            throw CalendarMCPError.invalidDateFormat("Date format should be YYYY-MM-DDTHH:mm:ssZ")
        }
        
        // Get target calendar
        let targetCalendar: EKCalendar
        if let calendarId = calendarId {
            let allCalendars = eventStore.calendars(for: .event)
            guard let specificCalendar = allCalendars.first(where: { $0.calendarIdentifier == calendarId }) else {
                throw CalendarMCPError.invalidArguments("Calendar with ID '\(calendarId)' not found")
            }
            guard specificCalendar.allowsContentModifications else {
                throw CalendarMCPError.invalidArguments("Calendar '\(specificCalendar.title)' does not allow modifications")
            }
            targetCalendar = specificCalendar
            print("📅 Using specific calendar: \(targetCalendar.title)")
        } else {
            // Use user's default calendar setting
            let calendarSettings = CalendarSettings.shared
            let allCalendars = eventStore.calendars(for: .event)
            
            if let defaultCalendarId = calendarSettings.defaultCalendarId,
               let userDefaultCalendar = allCalendars.first(where: { $0.calendarIdentifier == defaultCalendarId }) {
                targetCalendar = userDefaultCalendar
                print("📅 Using user's default calendar: \(targetCalendar.title)")
            } else {
                // Fallback to system default
                guard let systemDefaultCalendar = eventStore.defaultCalendarForNewEvents else {
                    throw CalendarMCPError.invalidArguments("No default calendar available")
                }
                targetCalendar = systemDefaultCalendar
                print("📅 Using system default calendar: \(targetCalendar.title)")
            }
        }
        
        // Create new event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.isAllDay = isAllDay
        event.alarms = alarms
        event.calendar = targetCalendar
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            print("📅 Event created successfully: \(title)")
            
            let outputFormatter = ISO8601DateFormatter()
            outputFormatter.timeZone = TimeZone.current
            
            // Convert EKAlarms to CalendarAlarm format
            let calendarAlarms = event.alarms?.map { ekAlarm in
                CalendarAlarm(
                    relativeOffset: ekAlarm.relativeOffset / 60.0, // Convert seconds to minutes
                    absoluteDate: ekAlarm.absoluteDate != nil ? outputFormatter.string(from: ekAlarm.absoluteDate!) : nil
                )
            } ?? []
            
            let calendarEvent = CalendarEvent(
                id: event.eventIdentifier ?? "",
                title: title,
                startDate: outputFormatter.string(from: startDate),
                endDate: outputFormatter.string(from: endDate),
                location: location,
                notes: notes,
                isAllDay: isAllDay,
                calendarId: event.calendar?.calendarIdentifier ?? "",
                calendarTitle: event.calendar?.title ?? "",
                alarms: calendarAlarms
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

// MARK: - PersonalSync Extensions
extension PersonalSync.CalendarEvent {
    /// Convert PersonalSync.CalendarEvent to local CalendarEvent for CalendarMCP compatibility
    func toLocalCalendarEvent() -> CalendarEvent {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        // TODO: Convert PersonalSync alarms to CalendarAlarm format when available
        let calendarAlarms: [CalendarAlarm] = []
        
        return CalendarEvent(
            id: self.eventIdentifier ?? UUID().uuidString,
            title: self.title ?? "No Title",
            startDate: formatter.string(from: self.startDate),
            endDate: formatter.string(from: self.endDate),
            location: self.location ?? "",
            notes: self.notes ?? "",
            isAllDay: self.isAllDay,
            calendarId: self.calendarIdentifier ?? "",
            calendarTitle: self.calendarTitle ?? "",
            alarms: calendarAlarms
        )
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
        CalendarReadResultView(
            step: step,
            showingCalendarDetail: showingCalendarDetail
        )
    }
    
    // MARK: - Calendar Update Result View
    static func createUpdateResultView(
        step: WorkflowStep,
        showingCalendarConfirmation: Binding<Bool>,
        eventToOpen: Binding<CalendarEvent?>
    ) -> some View {
        CalendarUpdateResultView(
            step: step,
            showingCalendarConfirmation: showingCalendarConfirmation,
            eventToOpen: eventToOpen
        )
    }
    
    // MARK: - Calendar Add Result View
    static func createAddResultView(
        step: WorkflowStep,
        showingCalendarConfirmation: Binding<Bool>,
        eventToOpen: Binding<CalendarEvent?>
    ) -> some View {
        CalendarAddResultView(
            step: step,
            showingCalendarConfirmation: showingCalendarConfirmation,
            eventToOpen: eventToOpen
        )
    }
    
    // MARK: - Calendar Remove Result View
    static func createRemoveResultView(
        step: WorkflowStep
    ) -> some View {
        CalendarRemoveResultView(step: step)
    }
    
    // MARK: - Helper Functions
    static func openCalendarApp() {
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
    
    static func openEventInCalendar(_ event: CalendarEvent) {
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
    
    // MARK: - Calendar Color Helper
    static func getCalendarColor(for calendarId: String) -> Color {
        // Ensure we're on main thread for EventKit operations
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return getCalendarColor(for: calendarId)
            }
        }
        
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event)
        
        if let calendar = calendars.first(where: { $0.calendarIdentifier == calendarId }),
           let cgColor = calendar.cgColor {
            return Color(cgColor)
        }
        
        // Default color if calendar not found
        return Color.blue
    }
    
    // MARK: - Event Time Formatting
    static func formatEventTime(startDate: String, endDate: String, isAllDay: Bool) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        guard let start = isoFormatter.date(from: startDate),
              let end = isoFormatter.date(from: endDate) else {
            return "Invalid time"
        }
        
        if isAllDay {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            return dateFormatter.string(from: start)
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            let calendar = Calendar.current
            if calendar.isDate(start, inSameDayAs: end) {
                // Same day
                return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
            } else {
                // Different days
                let dateTimeFormatter = DateFormatter()
                dateTimeFormatter.dateFormat = "MMM d, HH:mm"
                return "\(dateTimeFormatter.string(from: start)) - \(dateTimeFormatter.string(from: end))"
            }
        }
    }
    
    // MARK: - Date Range Formatting
    static func formatDateRange(from dateRange: DateRange) -> String {
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

// MARK: - Calendar Result Views with Theme Support
struct CalendarReadResultView: View {
    let step: WorkflowStep
    @Binding var showingCalendarDetail: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let calendarResponse = try? JSONDecoder().decode(
                   CalendarReadResponse.self,
                   from: jsonData
               )
            {
                // Simple compact view - clickable entire area
                HStack(spacing: 16) {
                    Image(systemName: calendarResponse.count > 0 ? "magnifyingglass" : "calendar.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(ThemeColors.text(for: colorScheme))
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(calendarResponse.count > 0 ? "Found \(calendarResponse.count) events in Calendar" : "No events found in Calendar")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.text(for: colorScheme))
                        
                        Text(CalendarMCP.formatDateRange(from: calendarResponse.dateRange))
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                    }
                    
                    Spacer()
                    
                    // Tap to view indicator (only show if there are events)
                    if calendarResponse.count > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.cardBackground(for: colorScheme))
                )
                .padding(.horizontal, 20)
                .onTapGesture {
                    // Only open detail if there are events
                    if calendarResponse.count > 0 {
                        showingCalendarDetail = true
                    }
                }
                .sheet(isPresented: $showingCalendarDetail) {
                    CalendarEventsDetailView(
                        title: "Read Calendar",
                        subtitle: CalendarMCP.formatDateRange(from: calendarResponse.dateRange),
                        events: calendarResponse.events
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct CalendarUpdateResultView: View {
    let step: WorkflowStep
    @Binding var showingCalendarConfirmation: Bool
    @Binding var eventToOpen: CalendarEvent?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let updateResponse = try? JSONDecoder().decode(
                   CalendarUpdateResponse.self,
                   from: jsonData
               )
            {
                // Simple card layout similar to the reference image
                HStack(spacing: 0) {
                    // Left color bar
                    Rectangle()
                        .fill(CalendarMCP.getCalendarColor(for: updateResponse.event.calendarId))
                        .frame(width: 4, height: 50)
                        .cornerRadius(2)
                        .padding(.leading, 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(updateResponse.event.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.text(for: colorScheme))
                            .lineLimit(2)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                            
                            Text(CalendarMCP.formatEventTime(
                                startDate: updateResponse.event.startDate,
                                endDate: updateResponse.event.endDate,
                                isAllDay: updateResponse.event.isAllDay
                            ))
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    // Success indicator
                    if updateResponse.success {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                            .padding(.trailing, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CalendarMCP.getCalendarColor(for: updateResponse.event.calendarId).opacity(0.25))
                )
                .padding(.horizontal, 20)
                .onTapGesture {
                    eventToOpen = updateResponse.event
                    showingCalendarConfirmation = true
                }
                .alert("Open in Calendar", isPresented: $showingCalendarConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open") {
                        if let event = eventToOpen {
                            CalendarMCP.openEventInCalendar(event)
                        }
                    }
                } message: {
                    if let event = eventToOpen {
                        Text("Do you want to open '\(event.title)' in the Calendar app?")
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct CalendarAddResultView: View {
    let step: WorkflowStep
    @Binding var showingCalendarConfirmation: Bool
    @Binding var eventToOpen: CalendarEvent?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let addResponse = try? JSONDecoder().decode(
                   CalendarAddResponse.self,
                   from: jsonData
               )
            {
                // Simple card layout similar to the reference image
                HStack(spacing: 0) {
                    // Left color bar
                    Rectangle()
                        .fill(CalendarMCP.getCalendarColor(for: addResponse.event.calendarId))
                        .frame(width: 4, height: 50)
                        .cornerRadius(2)
                        .padding(.leading, 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(addResponse.event.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.text(for: colorScheme))
                            .lineLimit(2)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                            
                            Text(CalendarMCP.formatEventTime(
                                startDate: addResponse.event.startDate,
                                endDate: addResponse.event.endDate,
                                isAllDay: addResponse.event.isAllDay
                            ))
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    // Success indicator
                    if addResponse.success {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                            .padding(.trailing, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(CalendarMCP.getCalendarColor(for: addResponse.event.calendarId).opacity(0.25))
                )
                .padding(.horizontal, 20)
                .onTapGesture {
                    eventToOpen = addResponse.event
                    showingCalendarConfirmation = true
                }
                .alert("Open in Calendar", isPresented: $showingCalendarConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open") {
                        if let event = eventToOpen {
                            CalendarMCP.openEventInCalendar(event)
                        }
                    }
                } message: {
                    if let event = eventToOpen {
                        Text("Do you want to open '\(event.title)' in the Calendar app?")
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct CalendarRemoveResultView: View {
    let step: WorkflowStep
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
                            .foregroundColor(ThemeColors.text(for: colorScheme))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(deleteResponse.success ? "Event Deleted Successfully" : "Failed to Delete Event")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(ThemeColors.text(for: colorScheme))
                            
                            Text(deleteResponse.message)
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText(for: colorScheme))
                        }

                        Spacer()

                        if deleteResponse.success {
                            Button(action: {
                                CalendarMCP.openCalendarApp()
                            }) {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.cardBackground(for: colorScheme))
                )
            } else {
                EmptyView()
            }
        }
    }
}
