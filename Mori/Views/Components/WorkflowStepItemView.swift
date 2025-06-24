import SwiftUI
import Foundation
import EventKit

// MARK: - Workflow Step Item View

struct WorkflowStepItemView: View {
    let step: WorkflowStep
    @State private var showingCalendarDetail = false
    @State private var showingErrorDetail = false
    @State private var showingCalendarConfirmation = false
    @State private var eventToOpen: CalendarEvent?

    var body: some View {
        // Dynamic rendering based on toolName and status
        if step.toolName == "read-calendar" && step.status == .result {
            renderCalendarReadResult()
        } else if step.toolName == "update-calendar" && step.status == .result {
            renderCalendarUpdateResult()
        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Calendar Read Result
    @ViewBuilder
    private func renderCalendarReadResult() -> some View {
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
                        Text("Found \(calendarResponse.count) events in Calendar")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text(formatDateRange(from: calendarResponse.dateRange))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button(action: {
                        openCalendarApp()
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Events list - show at most 3 events
                if !calendarResponse.events.isEmpty {
                    VStack(spacing: 12) {
                        // Display first 3 events
                        ForEach(Array(calendarResponse.events.prefix(3).enumerated()), id: \.offset) { index, event in
                            CalendarEventDetailRowWithButton(
                                event: event,
                                onOpenCalendar: {
                                    eventToOpen = event
                                    showingCalendarConfirmation = true
                                }
                            )
                        }
                        
                        // Show "more" button if there are more than 3 events
                        if calendarResponse.events.count > 3 {
                            Button(action: {
                                showingCalendarDetail = true
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
            .alert("Open in Calendar", isPresented: $showingCalendarConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Open") {
                    if let event = eventToOpen {
                        openEventInCalendar(event)
                    }
                }
            } message: {
                if let event = eventToOpen {
                    Text("Do you want to open '\(event.title)' in the Calendar app?")
                }
            }
            .sheet(isPresented: $showingCalendarDetail) {
                CalendarEventsDetailView(
                    title: "Read Calendar",
                    subtitle: formatDateRange(from: calendarResponse.dateRange),
                    events: calendarResponse.events
                )
            }

        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Calendar Update Result
    @ViewBuilder
    private func renderCalendarUpdateResult() -> some View {
        if let resultValue = step.details["result"],
            let jsonData = resultValue.data(using: .utf8),
            let updateResponse = try? JSONDecoder().decode(
                CalendarUpdateResponse.self,
                from: jsonData
            )
        {
            CalendarEventDetailRowWithButton(
                    event: updateResponse.event,
                    onOpenCalendar: {
                        eventToOpen = updateResponse.event
                        showingCalendarConfirmation = true
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            (updateResponse.success ? Color.green : Color.red)
                                .opacity(0.2)
                        )
                )
            .padding(.horizontal, 20)
            
            .alert("Open in Calendar", isPresented: $showingCalendarConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Open") {
                    if let event = eventToOpen {
                        openEventInCalendar(event)
                    }
                }
            } message: {
                if let event = eventToOpen {
                    Text("Do you want to open '\(event.title)' in the Calendar app?")
                }
            }

        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Default Workflow Step
    @ViewBuilder
    private func renderDefaultWorkflowStep() -> some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: iconForStatus)
                .font(.title2)
                .foregroundColor(step.status == .error ? .red : .white)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !step.toolName.isEmpty {
                        Text(step.toolName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Add "Tap for details" hint for error status
                    if step.status == .error {
                        Text("Tap for details")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                if !step.details.isEmpty {
                    // For error status, show only short message in the main view
                    if step.status == .error {
                        if let shortMessage = step.details["short_message"], !shortMessage.isEmpty {
                            Text(shortMessage)
                                .font(.body)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        } else if let errorType = step.details["error_type"], !errorType.isEmpty {
                            Text(errorType)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                    } else {
                        // For non-error status, show all details as before
                        ForEach(Array(step.details.keys.sorted()), id: \.self) {
                            key in
                            if let value = step.details[key], !value.isEmpty {
                                Text(value)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    step.status == .error
                        ? Color.red.opacity(0.2) : Color.white.opacity(0.1)
                )
        )
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            if step.status == .error {
                showingErrorDetail = true
            }
        }
        .sheet(isPresented: $showingErrorDetail) {
            // Use full details for error detail view
            let detailContent = step.details["full_details"] ?? step.toolName
            ErrorDetailView(errorDetail: detailContent)
        }
    }

    private var iconForStatus: String {
        // Check the step details to determine the appropriate icon
        if let action = step.details["action"], action.contains("Searching") {
            return "magnifyingglass"
        } else if let result = step.details["result"] {
            if result.contains("Founded") || result.contains("Found") {
                return "magnifyingglass"
            } else if result.contains("Updated") {
                return "pencil"
            }
        }

        // Default icons based on status
        switch step.status {
        case .scheduled:
            return "clock"
        case .executing:
            return "magnifyingglass"
        case .result:
            return "checkmark"
        case .error:
            return "xmark"
        case .finalStatus:
            return "checkmark.circle"
        case .llmThinking:
            return "brain"
        }
    }
    
    // MARK: - Calendar Functions
    private func openCalendarApp() {
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
    
    private func openEventInCalendar(_ event: CalendarEvent) {
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
    private func formatDateRange(from dateRange: DateRange) -> String {
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

// MARK: - Calendar Event Detail Row with Button
struct CalendarEventDetailRowWithButton: View {
    let event: CalendarEvent
    let onOpenCalendar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                // Title and time
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            if event.isAllDay {
                                Text("All day")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text(
                                    "\(formatDateTime(event.startDate)) - \(formatTime(event.endDate))"
                                )
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }

                    Spacer()
                }

                // Location (if available)
                if !event.location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(event.location)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }

                // Notes (if available)
                if !event.notes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(event.notes)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
            // Open calendar button
            Button(action: onOpenCalendar) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func formatDateTime(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func formatTime(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        return "Time"
    }
} 