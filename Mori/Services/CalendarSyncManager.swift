import Foundation
import PersonalSync

class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()
    
    @Published var isActive: Bool = false
    @Published var eventCount: Int = 0
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var recentEvents: [PersonalSync.CalendarEvent] = []
    @Published var errorMessage: String?
    
    private var calendarSync: CalendarSync?
    
    private init() {
        setupCalendarSync()
    }
    
    private func setupCalendarSync() {
        do {
            calendarSync = try CalendarSync()
            
            // Setup callbacks
            calendarSync?.onSyncStatusChanged = { [weak self] status in
                DispatchQueue.main.async {
                    self?.syncStatus = status
                    self?.isActive = status == .syncing
                }
            }
            
            calendarSync?.onEventUpdated = { [weak self] event, updateType in
                DispatchQueue.main.async {
                    self?.loadEventData()
                }
            }
            
            // Initial data load
            loadEventData()
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to initialize calendar sync: \(error.localizedDescription)"
            }
        }
    }
    
    func loadEventData() {
        guard let calendarSync = calendarSync else { return }
        
        do {
            let allEvents = try calendarSync.getAllEvents()
            let upcomingEvents = try calendarSync.getUpcomingEvents(limit: 5)
            
            DispatchQueue.main.async {
                self.eventCount = allEvents.count
                self.recentEvents = upcomingEvents
                self.lastSyncTime = calendarSync.lastSyncTime
                self.errorMessage = nil
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func performSync() {
        guard let calendarSync = calendarSync else { return }
        
        calendarSync.forceSync()
    }
    
    func pause() {
        calendarSync?.pause()
    }
    
    func resume() {
        calendarSync?.resume()
    }
}

// Extension to provide sync status string representation
extension SyncStatus {
    var displayString: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing"
        case .error:
            return "Error"
        case .synced:
            return "Synced"
        default:
            return "Success"
        }
    }
}





// Extension to add convenience method for getting local format events
extension CalendarSyncManager {
    /// Get recent events in local CalendarEvent format for UI compatibility
    var recentEventsAsLocal: [CalendarEvent] {
        return recentEvents.map { $0.toLocalCalendarEvent() }
    }
}
