import SwiftUI
import Foundation

// MARK: - Calendar Event Components

struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(event.startDate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                if !event.isAllDay {
                    Text(formatTime(event.endDate))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 45)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !event.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(event.location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
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

// MARK: - Calendar Events Detail View
struct CalendarEventsDetailView: View {
    let title: String
    let subtitle: String 
    let events: [CalendarEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Found \(events.count) events")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Add subtitle display
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.top, 2)
                        }

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()
                        .background(Color.white.opacity(0.2))
                }

                // Events list
                if !events.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(events, id: \.id) {
                                event in
                                CalendarEventDetailRow(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No events found")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 16)
                        Spacer()
                    }
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Calendar Event Detail Row Component
struct CalendarEventDetailRow: View {
    let event: CalendarEvent

    var body: some View {
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

            // Calendar info (if available)
            if !event.calendarTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(event.calendarTitle)
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

// MARK: - Calendar Event Detail Row with Button Component
struct CalendarEventDetailRowWithButton<ButtonContent: View>: View {
    let event: CalendarEvent
    let buttonContent: () -> ButtonContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and time with button
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
                
                buttonContent()
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

            // Calendar info (if available)
            if !event.calendarTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(event.calendarTitle)
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

// MARK: - Calendar Info Row Component
struct CalendarInfoRow: View {
    let calendar: CalendarInfo

    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Circle()
                .fill(Color(hex: calendar.color ?? "#007AFF"))
                .frame(width: 12, height: 12)

            // Calendar details
            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(calendar.type.capitalized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )

                    if !calendar.allowsContentModifications {
                        Image(systemName: "lock")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            Spacer()

            // Calendar ID (truncated)
            Text(String(calendar.id.prefix(8)) + "...")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .monospaced()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}