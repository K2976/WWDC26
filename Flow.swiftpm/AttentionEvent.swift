import Foundation

// MARK: - Attention Event Types

enum AttentionEvent: String, CaseIterable, Identifiable {
    case appSwitch = "App Switch"
    case notification = "Notification"
    case mindWandered = "Mind Wandered"
    case idle = "Idle"
    case rapidSwitch = "Rapid Switching"
    
    var id: String { rawValue }
    
    var loadIncrease: Double {
        switch self {
        case .appSwitch: return 4
        case .notification: return 3
        case .mindWandered: return 2
        case .idle: return 3
        case .rapidSwitch: return 5
        }
    }
    
    var symbol: String {
        switch self {
        case .appSwitch: return "rectangle.on.rectangle"
        case .notification: return "bell.fill"
        case .mindWandered: return "cloud.fill"
        case .idle: return "powersleep"
        case .rapidSwitch: return "arrow.triangle.swap"
        }
    }
    
    var shortcutLabel: String {
        switch self {
        case .appSwitch: return "⌘1"
        case .notification: return "⌘2"
        case .mindWandered: return "Space"
        case .idle: return ""
        case .rapidSwitch: return ""
        }
    }
    
    /// Whether this event appears as a manual button in the dashboard
    var isManual: Bool {
        switch self {
        case .appSwitch, .notification, .mindWandered: return true
        case .idle, .rapidSwitch: return false
        }
    }
}

// MARK: - Event Record

struct AttentionEventRecord: Identifiable {
    let id = UUID()
    let event: AttentionEvent
    let timestamp: Date
    let scoreAfter: Double
}

// MARK: - History Snapshot

struct LoadSnapshot: Identifiable {
    let id = UUID()
    let timestamp: Date
    let score: Double
}

// MARK: - Day Summary

struct DaySummary: Identifiable {
    let id = UUID()
    let date: Date
    let averageScore: Double
    let peakScore: Double
    let eventCount: Int
    let totalMinutes: Double
}

// MARK: - Session Record

struct SessionRecord: Identifiable {
    let id = UUID()
    var name: String?
    let startTime: Date
    let endTime: Date
    let startScore: Double
    let endScore: Double
    let averageScore: Double
    let peakScore: Double
    let eventCount: Int
    let events: [AttentionEventRecord]
    var realDuration: TimeInterval? = nil  // Wall-clock duration (fixes demo mode)
}
