import SwiftUI

// MARK: - Settings Views
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCalendarSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Calendar") {
                    NavigationLink(destination: CalendarSettingsView()) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            
                            Text("Calendar Settings")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CalendarSettingsView: View {
    @StateObject private var calendarSettings = CalendarSettings.shared
    @State private var availableCalendars: [CalendarInfo] = []
    @State private var calendarsByType: [String: [CalendarInfo]] = [:]
    @State private var showingDefaultCalendarSelection = false
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: DefaultCalendarSelectionView()) {
                    HStack {
                        Text("Default Calendar")
                        Spacer()
                        if let defaultCalendarId = calendarSettings.defaultCalendarId,
                           let defaultCalendar = availableCalendars.first(where: { $0.id == defaultCalendarId }) {
                            Text(defaultCalendar.title)
                                .foregroundColor(.secondary)
                        } else {
                            Text("System Default")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            ForEach(Array(calendarsByType.keys.sorted()), id: \.self) { type in
                Section(type.capitalized) {
                    ForEach(calendarsByType[type] ?? [], id: \.id) { calendar in
                        CalendarSelectionRow(
                            calendar: calendar,
                            isSelected: calendarSettings.isCalendarEnabled(calendar.id),
                            onToggle: {
                                calendarSettings.toggleCalendar(calendar.id)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Calendar Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalendars()
        }
    }
    
    private func loadCalendars() {
        availableCalendars = CalendarMCP.getAvailableCalendarsInfo()
        calendarSettings.initializeWithAllCalendars(availableCalendars)
        
        // Group calendars by type
        calendarsByType = Dictionary(grouping: availableCalendars) { calendar in
            switch calendar.type {
            case "caldav":
                return "iCloud"
            case "local":
                return "Local"
            case "exchange":
                return "Exchange"
            case "subscription":
                return "Subscription"
            case "birthday":
                return "Birthday"
            default:
                return "Other"
            }
        }
    }
}

struct DefaultCalendarSelectionView: View {
    @StateObject private var calendarSettings = CalendarSettings.shared
    @State private var availableCalendars: [CalendarInfo] = []
    @State private var writableCalendarsByType: [String: [CalendarInfo]] = [:]
    
    var body: some View {
        List {
            ForEach(Array(writableCalendarsByType.keys.sorted()), id: \.self) { type in
                Section(type.capitalized) {
                    ForEach(writableCalendarsByType[type] ?? [], id: \.id) { calendar in
                        DefaultCalendarRow(
                            calendar: calendar,
                            isSelected: calendarSettings.defaultCalendarId == calendar.id,
                            onSelect: {
                                calendarSettings.defaultCalendarId = calendar.id
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Default Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadWritableCalendars()
        }
    }
    
    private func loadWritableCalendars() {
        availableCalendars = CalendarMCP.getAvailableCalendarsInfo()
        let writableCalendars = availableCalendars.filter { $0.allowsContentModifications }
        
        // Group writable calendars by type
        writableCalendarsByType = Dictionary(grouping: writableCalendars) { calendar in
            switch calendar.type {
            case "caldav":
                return "iCloud"
            case "local":
                return "Local"
            case "exchange":
                return "Exchange"
            case "subscription":
                return "Subscription"
            case "birthday":
                return "Birthday"
            default:
                return "Other"
            }
        }
    }
}

struct CalendarSelectionRow: View {
    let calendar: CalendarInfo
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            onToggle()
        }) {
            HStack(spacing: 12) {
                // Calendar color and checkmark
                ZStack {
                    if isSelected {
                        // Selected state: filled circle with calendar color background
                        Circle()
                            .fill(Color(hex: calendar.color ?? "#007AFF"))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // Unselected state: only border with calendar color
                        Circle()
                            .stroke(Color(hex: calendar.color ?? "#007AFF"), lineWidth: 1)
                            .frame(width: 24, height: 24)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .foregroundColor(.primary)
                        .font(.body)
                    
                    // if !calendar.allowsContentModifications {
                    //     Text("Read-only")
                    //         .foregroundColor(.secondary)
                    //         .font(.caption)
                    // }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle()) // Make entire area tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DefaultCalendarRow: View {
    let calendar: CalendarInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            onSelect()
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: calendar.color ?? "#007AFF"))
                    .frame(width: 24, height: 24)
                
                Text(calendar.title)
                    .foregroundColor(.primary)
                    .font(.body)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle()) // Make entire area tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Calendar Settings") {
    NavigationStack {
        CalendarSettingsView()
    }
}

