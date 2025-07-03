import SwiftUI
import Foundation
import EventKit

// MARK: - Workflow Step Item View

struct WorkflowStepItemView: View {
    let step: WorkflowStep
    let onRetry: () -> Void
    @State private var showingCalendarDetail = false
    @State private var showingErrorDetail = false
    @State private var showingCalendarConfirmation = false
    @State private var eventToOpen: CalendarEvent?

    var body: some View {
        // Dynamic rendering based on toolName and status
        if step.toolName == "read-calendar" && step.status == .result {
            CalendarMCP.createReadResultView(
                step: step,
                showingCalendarDetail: $showingCalendarDetail,
                showingCalendarConfirmation: $showingCalendarConfirmation,
                eventToOpen: $eventToOpen
            )
        } else if step.toolName == "update-calendar" && step.status == .result {
            CalendarMCP.createUpdateResultView(
                step: step,
                showingCalendarConfirmation: $showingCalendarConfirmation,
                eventToOpen: $eventToOpen
            )
        } else if step.toolName == "add-calendar" && step.status == .result {
            CalendarMCP.createAddResultView(
                step: step,
                showingCalendarConfirmation: $showingCalendarConfirmation,
                eventToOpen: $eventToOpen
            )
        } else if step.toolName == "remove-calendar" && step.status == .result {
            CalendarMCP.createRemoveResultView(
                step: step
            )
        } else if step.toolName == "update-memory" && step.status == .result {
            MemoryMCP.createUpdateResultView(
                step: step
            )
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

            // Add retry button for error status
            if step.status == .error {
                Button(action: onRetry) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Retry")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                .frame(maxHeight: .infinity)
                .padding(.leading, 12)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
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
    

}

// // MARK: - Calendar Event Detail Row with Button
// struct CalendarEventDetailRowWithButton<ButtonContent: View>: View {
//     let event: CalendarEvent
//     let buttonContent: ButtonContent

//     init(event: CalendarEvent, @ViewBuilder buttonContent: () -> ButtonContent) {
//         self.event = event
//         self.buttonContent = buttonContent()
//     }

//     var body: some View {
//         HStack(spacing: 12) {
//             VStack(alignment: .leading, spacing: 12) {
//                 // Title and time
//                 HStack(alignment: .top, spacing: 12) {
//                     VStack(alignment: .leading, spacing: 4) {
//                         Text(event.title)
//                             .font(.headline)
//                             .fontWeight(.medium)
//                             .foregroundColor(.white)
//                             .lineLimit(1)
//                             .multilineTextAlignment(.leading)

//                         HStack(spacing: 8) {
//                             Image(systemName: "clock")
//                                 .font(.caption)
//                                 .foregroundColor(.white.opacity(0.7))

//                             if event.isAllDay {
//                                 Text("All day")
//                                     .font(.subheadline)
//                                     .foregroundColor(.white.opacity(0.8))
//                             } else {
//                                 Text(
//                                     "\(formatDateTime(event.startDate)) - \(formatTime(event.endDate))"
//                                 )
//                                 .font(.subheadline)
//                                 .foregroundColor(.white.opacity(0.8))
//                             }
//                         }
//                     }

//                     Spacer()
//                 }

//                 // Location (if available)
//                 if !event.location.isEmpty {
//                     HStack(spacing: 8) {
//                         Image(systemName: "location")
//                             .font(.caption)
//                             .foregroundColor(.white.opacity(0.7))

//                         Text(event.location)
//                             .font(.subheadline)
//                             .foregroundColor(.white.opacity(0.8))
//                             .lineLimit(1)
//                             .multilineTextAlignment(.leading)
//                     }
//                 }

//                 // Notes (if available)
//                 if !event.notes.isEmpty {
//                     HStack(alignment: .top, spacing: 8) {
//                         Image(systemName: "note.text")
//                             .font(.caption)
//                             .foregroundColor(.white.opacity(0.7))

//                         Text(event.notes)
//                             .font(.subheadline)
//                             .foregroundColor(.white.opacity(0.8))
//                             .lineLimit(1)
//                             .multilineTextAlignment(.leading)
//                     }
//                 }
//             }
            
//             // Button content from outside
//             buttonContent
//         }
//         .padding(16)
//         .background(
//             RoundedRectangle(cornerRadius: 12)
//                 .fill(Color.white.opacity(0.1))
//         )
//     }

//     private func formatDateTime(_ dateString: String) -> String {
//         // Try ISO8601DateFormatter first
//         let isoFormatter = ISO8601DateFormatter()
//         isoFormatter.timeZone = TimeZone.current

//         if let date = isoFormatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "MMM d, HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }

//         // Fallback to manual DateFormatter
//         let formatter = DateFormatter()
//         formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
//         formatter.timeZone = TimeZone.current

//         if let date = formatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "MMM d, HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }

//         return dateString
//     }

//     private func formatTime(_ dateString: String) -> String {
//         // Try ISO8601DateFormatter first
//         let isoFormatter = ISO8601DateFormatter()
//         isoFormatter.timeZone = TimeZone.current

//         if let date = isoFormatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }

//         // Fallback to manual DateFormatter
//         let formatter = DateFormatter()
//         formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
//         formatter.timeZone = TimeZone.current

//         if let date = formatter.date(from: dateString) {
//             let displayFormatter = DateFormatter()
//             displayFormatter.dateFormat = "HH:mm"
//             displayFormatter.timeZone = TimeZone.current
//             return displayFormatter.string(from: date)
//         }

//         return "Time"
//     }
// } 