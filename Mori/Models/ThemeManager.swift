import SwiftUI
import Foundation

// MARK: - Theme Manager
enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: "themeMode")
            updateAppearance()
        }
    }
    
    @Published var isDarkMode: Bool = false
    
    private init() {
        // Load saved theme mode
        if let savedMode = UserDefaults.standard.string(forKey: "themeMode"),
           let mode = ThemeMode(rawValue: savedMode) {
            currentMode = mode
        }
        
        // Update appearance initially
        updateAppearance()
        
        // Listen for system theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func systemThemeChanged() {
        if currentMode == .system {
            updateAppearance()
        }
    }
    
    func updateAppearance() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            switch self.currentMode {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
                self.isDarkMode = window.traitCollection.userInterfaceStyle == .dark
            case .light:
                window.overrideUserInterfaceStyle = .light
                self.isDarkMode = false
            case .dark:
                window.overrideUserInterfaceStyle = .dark
                self.isDarkMode = true
            }
        }
    }
    
    func setTheme(_ mode: ThemeMode) {
        currentMode = mode
    }
}

// MARK: - Theme Colors
struct ThemeColors {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.systemBackground)
    }
    
    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground)
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6)
    }
    
    static func text(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    static func textContrast(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray : Color.secondary
    }
    
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
    }
} 
