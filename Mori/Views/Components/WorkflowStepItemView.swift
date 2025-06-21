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

                VStack(alignment: .leading, spacing: 4) {
                    Text("Founded \(calendarResponse.count) events in Calendar")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text("Tap for details")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

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
                CalendarEventsDetailView(calendarResponse: calendarResponse)
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(updateResponse.message)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    if !updateResponse.event.title.isEmpty {
                        Text("Event: \(updateResponse.event.title)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
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
} 