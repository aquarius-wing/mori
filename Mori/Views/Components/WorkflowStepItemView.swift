import SwiftUI
import Foundation

// MARK: - Workflow Step Item View

struct WorkflowStepItemView: View {
    let step: WorkflowStep
    @State private var showingCalendarDetail = false
    @State private var showingErrorDetail = false

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
            // Simplified view showing only summary
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                Text("Found \(calendarResponse.count) events in Calendar")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.2))
            )
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                showingCalendarDetail = true
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
            // Simplified view showing only summary
            HStack(spacing: 16) {
                Image(
                    systemName: updateResponse.success
                        ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.title2)
                .foregroundColor(updateResponse.success ? .green : .red)
                .frame(width: 24, height: 24)

                Text(updateResponse.message)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        (updateResponse.success ? Color.green : Color.red)
                            .opacity(0.2)
                    )
            )
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                showingCalendarDetail = true
            }
            .sheet(isPresented: $showingCalendarDetail) {
                CalendarEventsDetailView(
                    title: updateResponse.success ? "Update Calendar" : "Calendar Update Failed",
                    subtitle: updateResponse.event.title.isEmpty ? "Event details" : "Event: \(updateResponse.event.title)",
                    events: [updateResponse.event]
                )
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