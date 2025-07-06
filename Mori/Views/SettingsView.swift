import SwiftUI
import MarkdownUI

// MARK: - Settings Views
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCalendarSettings = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    NavigationLink(destination: ThemeSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(.orange)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading) {
                                Text("Theme Settings")
                                Text(themeManager.currentMode.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Memory") {
                    NavigationLink(destination: MemoryView()) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                                .frame(width: 24, height: 24)
                            
                            Text("Memory Management")
                        }
                    }
                }
                
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

struct MemoryView: View {
    @StateObject private var memorySettings = MemorySettings.shared
    @State private var isEditingMemory = false
    @State private var editableMemory = ""
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if memorySettings.userMemory.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Memory Records")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Your personal information and preferences will appear here as you interact with Mori.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if isEditingMemory {
                        // Edit mode
                        VStack(spacing: 0) {
                            // Edit toolbar
                            HStack {
                                Button("Cancel") {
                                    isEditingMemory = false
                                    editableMemory = memorySettings.userMemory
                                }
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Button("Save") {
                                    memorySettings.updateMemory(editableMemory)
                                    isEditingMemory = false
                                }
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemBackground))
                            .overlay(
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundColor(Color(UIColor.separator)),
                                alignment: .bottom
                            )
                            
                            // Text editor
                            TextEditor(text: $editableMemory)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    } else {
                        // View mode with markdown rendering
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Markdown(memorySettings.userMemory)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !memorySettings.userMemory.isEmpty {
                            Button(action: {
                                showingClearConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if !memorySettings.userMemory.isEmpty {
                            Button(action: {
                                if isEditingMemory {
                                    memorySettings.updateMemory(editableMemory)
                                    isEditingMemory = false
                                } else {
                                    editableMemory = memorySettings.userMemory
                                    isEditingMemory = true
                                }
                            }) {
                                Image(systemName: isEditingMemory ? "checkmark" : "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .onAppear {
                editableMemory = memorySettings.userMemory
            }
            .alert("Clear Memory", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    memorySettings.clearMemory()
                    editableMemory = ""
                }
            } message: {
                Text("Are you sure you want to clear all memory records? This action cannot be undone.")
            }
        }
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

#Preview("Memory View - Empty") {
    NavigationStack {
        MemoryView()
    }
}

// MARK: - Theme Settings View
struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    ThemeSelectionRow(
                        mode: mode,
                        isSelected: themeManager.currentMode == mode,
                        onSelect: {
                            themeManager.setTheme(mode)
                        }
                    )
                }
            } header: {
                Text("Select Theme")
            } footer: {
                Text("Choose the appearance theme for the app. System will automatically switch based on your system settings.")
            }
        }
        .navigationTitle("Theme Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThemeSelectionRow: View {
    let mode: ThemeMode
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
                Image(systemName: mode.icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(mode.displayName)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch mode {
        case .system:
            return .primary
        case .light:
            return .orange
        case .dark:
            return .indigo
        }
    }
}

#Preview("Memory View - With Content") {
    NavigationStack {
        MemoryView()
    }
    .onAppear {
        MemorySettings.shared.updateMemory("""
        - 用户饮食偏好
          - 用户喜欢吃辣但是无法接受非常辣的程度，比如火鸡面等
        - 用户家庭信息
          - 有一个女儿名叫Lucy
          - 女儿就读于Bay Area Technology School
        - 用户定义
          - 当用户说mauri时，通常指的是Mori应用
        """)
    }
}

#Preview("Theme Settings") {
    NavigationStack {
        ThemeSettingsView()
    }
}

