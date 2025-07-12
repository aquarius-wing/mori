import SwiftUI

// MARK: - Status Indicator View
struct StatusIndicator: View {
    let status: String
    let stepStatus: WorkflowStepStatus
    
    var body: some View {
        HStack {
            Text(stepStatus.icon)
            Text(status)
                .font(.caption)
                .foregroundColor(stepStatus == .error ? .red : .secondary)
            
            if stepStatus != .finalStatus && stepStatus != .error {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(stepStatus == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Calendar Card View
struct CalendarCardView: View {
    let calendarResponse: CalendarReadResponse
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Calendar Events")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("\(calendarResponse.count) events found")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                
                // Date range indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDateRange())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Events list
            if !calendarResponse.events.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(calendarResponse.events.prefix(3).enumerated()), id: \.offset) { index, event in
                        CalendarEventRow(event: event)
                    }
                    
                    if calendarResponse.events.count > 3 {
                        HStack {
                            Spacer()
                            Text("+\(calendarResponse.events.count - 3) more events")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.6))
                    Text("No events found")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDateRange() -> String {
        // Try ISO8601DateFormatter first (which is what CalendarMCP uses)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        
        // Try to parse with ISO8601 first
        if let startDate = isoFormatter.date(from: calendarResponse.dateRange.startDate),
           let endDate = isoFormatter.date(from: calendarResponse.dateRange.endDate) {
            let startStr = displayFormatter.string(from: startDate)
            let endStr = displayFormatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }
        
        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current
        
        if let startDate = formatter.date(from: calendarResponse.dateRange.startDate),
           let endDate = formatter.date(from: calendarResponse.dateRange.endDate) {
            let startStr = displayFormatter.string(from: startDate)
            let endStr = displayFormatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }
        
        return "Date Range"
    }
}

// MARK: - Calendar Update Card View
struct CalendarUpdateCardView: View {
    let updateResponse: CalendarUpdateResponse
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: updateResponse.success ? "checkmark.circle" : "xmark.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(updateResponse.success ? "Event Updated" : "Update Failed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text(updateResponse.message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                
                // Success/Failure indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: updateResponse.success ? "calendar.badge.plus" : "calendar.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Updated event details
            if updateResponse.success {
                VStack(spacing: 12) {
                    CalendarEventRow(event: updateResponse.event)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Failed to update event")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: updateResponse.success ? [
                    Color.green.opacity(0.8),
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.4)
                ] : [
                    Color.red.opacity(0.8),
                    Color.orange.opacity(0.6),
                    Color.pink.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Calendar Event Row
// struct CalendarEventRow: View {
//     let event: CalendarEvent
    
//     var body: some View {
//         HStack(spacing: 12) {
//             // Time indicator
//             VStack(spacing: 4) {
//                 if event.isAllDay {
//                     Text("All Day")
//                         .font(.caption2)
//                         .fontWeight(.medium)
//                         .foregroundColor(.white.opacity(0.9))
//                 } else {
//                     Text(formatTime(event.startDate))
//                         .font(.caption2)
//                         .fontWeight(.medium)
//                         .foregroundColor(.white.opacity(0.9))
//                     Text(formatTime(event.endDate))
//                         .font(.caption2)
//                         .foregroundColor(.white.opacity(0.7))
//                 }
//             }
//             .frame(width: 45)
            
//             // Event details
//             VStack(alignment: .leading, spacing: 2) {
//                 Text(event.title)
//                     .font(.subheadline)
//                     .fontWeight(.medium)
//                     .foregroundColor(.white)
//                     .lineLimit(1)
                
//                 if !event.location.isEmpty {
//                     HStack(spacing: 4) {
//                         Image(systemName: "location")
//                             .font(.caption2)
//                         Text(event.location)
//                             .font(.caption)
//                             .lineLimit(1)
//                     }
//                     .foregroundColor(.white.opacity(0.8))
//                 }
//             }
            
//             Spacer()
//         }
//         .padding(.horizontal, 16)
//         .padding(.vertical, 12)
//         .background(
//             RoundedRectangle(cornerRadius: 12)
//                 .fill(Color.white.opacity(0.15))
//         )
//     }
    
//     private func formatTime(_ dateString: String) -> String {
//         // Try ISO8601DateFormatter first (which is what CalendarMCP uses)
//         let isoFormatter = ISO8601DateFormatter()
//         isoFormatter.timeZone = TimeZone.current // Use current timezone to match CalendarMCP output
        
//         if let date = isoFormatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }
        
//         // Fallback to manual DateFormatter if ISO8601 fails
//         let formatter = DateFormatter()
//         formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX" // Support different timezone formats
//         formatter.timeZone = TimeZone.current
        
//         if let date = formatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }
        
//         // Debug: print the actual string format to help troubleshoot
//         print("⚠️ Failed to parse date: \(dateString)")
//         return "Time"
//     }
// }

// MARK: - Workflow View
struct WorkflowView: View {
    let steps: [WorkflowStep]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                let step = steps[index]
                
                if step.status == .scheduled || step.status == .executing || step.status == .result || step.status == .finalStatus {
                    WorkflowStepView(step: step)
                } else if step.status == .error {
                    WorkflowErrorView(step: step)
                }
            }
        }
    }
}

// MARK: - Standard Workflow Step View
struct WorkflowStepView: View {
    let step: WorkflowStep
    @State private var isExpanded = false
    
    var body: some View {
        // Special handling for calendar tools - show only the card without wrapper
        if step.toolName == "read-calendar" && step.status == .result,
           let resultValue = step.details["result"],
           let jsonData = resultValue.data(using: .utf8),
           let calendarResponse = try? JSONDecoder().decode(CalendarReadResponse.self, from: jsonData) {
            CalendarCardView(calendarResponse: calendarResponse)
        } else if step.toolName == "update-calendar" && step.status == .result,
                  let resultValue = step.details["result"],
                  let jsonData = resultValue.data(using: .utf8),
                  let updateResponse = try? JSONDecoder().decode(CalendarUpdateResponse.self, from: jsonData) {
            CalendarUpdateCardView(updateResponse: updateResponse)
        } else {
            // Standard workflow step with wrapper
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Text(step.status.icon)
                        Text("\(step.toolName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if !step.details.isEmpty {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .disabled(step.details.isEmpty)
                
                StandardStepDetailsView(step: step, isExpanded: $isExpanded)
            }
            .padding()
            .background(
                step.status == .result ? Color.blue.opacity(0.05) :
                step.status == .executing ? Color.orange.opacity(0.05) :
                step.status == .scheduled ? Color("muted") : Color("muted")
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Standard Step Details View
struct StandardStepDetailsView: View {
    let step: WorkflowStep
    @Binding var isExpanded: Bool
    
    var body: some View {
        if isExpanded && !step.details.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(step.details.keys.sorted()), id: \.self) { key in
                    if let value = step.details[key] {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(key.capitalized):")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(value)
                                .font(.caption)
                                .padding(8)
                                .background(
                                    step.status == .result ? Color.blue.opacity(0.1) : 
                                    step.status == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)
                                )
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(.leading, 16)
        }
    }
}

// MARK: - Error View
struct WorkflowErrorView: View {
    let step: WorkflowStep
    
    var body: some View {
        HStack {
            Text(step.status.icon)
            Text(step.toolName)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Message View
struct MessageView: View {
    let message: ChatMessage
    var onPlayTTS: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 12) {
            // Workflow steps (only for assistant messages)
            if !message.isUser && !message.workflowSteps.isEmpty {
                WorkflowView(steps: message.workflowSteps)
            }
            
            // Message bubble
            MessageBubble(message: message, onPlayTTS: onPlayTTS)
        }
    }
} 