import Foundation
import SwiftUI

// MARK: - Session Manager

@MainActor
@Observable
final class SessionManager {
    
    private(set) var isSessionActive: Bool = true
    private(set) var sessionStartTime: Date = Date()
    private(set) var hasPickedScore: Bool = false
    private(set) var completedSessions: [SessionRecord] = []
    private(set) var savedSessions: [SessionRecord] = []
    private(set) var showingSummary: Bool = false
    private(set) var lastSession: SessionRecord?
    var pendingAttentionPicker: Bool = false
    
    // 7-day history
    private(set) var weekHistory: [DaySummary] = []
    
    init(isDemoMode: Bool = true) {
        if isDemoMode {
            generateMockHistory()
        } else {
            generateEmptyHistory()
        }
    }
    
    /// Toggle demo mode at runtime — regenerates or clears mock history
    func setDemoMode(_ enabled: Bool) {
        if enabled {
            generateMockHistory()
        } else {
            generateEmptyHistory()
        }
    }
    
    func startNewSession(engine: CognitiveLoadEngine) {
        sessionStartTime = Date()
        isSessionActive = true
        hasPickedScore = false
        showingSummary = false
        engine.resetSession()
    }
    
    func endSession(engine: CognitiveLoadEngine) {
        let record = engine.buildSessionRecord()
        lastSession = record
        completedSessions.append(record)
        isSessionActive = false
        showingSummary = true
        
        // Update today in week history
        updateTodayHistory(record: record)
    }
    
    func saveSession(name: String, engine: CognitiveLoadEngine) {
        guard var session = lastSession else { return }
        session.name = name.isEmpty ? "Session" : name
        savedSessions.append(session)
        
        // Update day history with this saved session
        updateTodayHistory(record: session)
        
        // Reset and start new
        showingSummary = false
        startNewSession(engine: engine)
    }
    
    func savedSessions(for date: Date) -> [SessionRecord] {
        let calendar = Calendar.current
        return savedSessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    func dismissSummary() {
        showingSummary = false
    }
    
    var sessionDuration: TimeInterval {
        guard hasPickedScore else { return 0 }
        return Date().timeIntervalSince(sessionStartTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func beginSession() {
        sessionStartTime = Date()
        hasPickedScore = true
    }
    
    // MARK: - Mock History
    
    private func generateMockHistory() {
        let calendar = Calendar.current
        var days: [DaySummary] = []
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            let avgScore: Double
            let peakScore: Double
            let eventCount: Int
            let minutes: Double
            
            switch i {
            case 0:
                avgScore = 35
                peakScore = 65
                eventCount = 8
                minutes = 45
            case 1:
                avgScore = 52
                peakScore = 88
                eventCount = 15
                minutes = 120
            case 2:
                avgScore = 28
                peakScore = 55
                eventCount = 6
                minutes = 90
            case 3:
                avgScore = 67
                peakScore = 92
                eventCount = 22
                minutes = 180
            case 4:
                avgScore = 41
                peakScore = 71
                eventCount = 11
                minutes = 60
            case 5:
                avgScore = 33
                peakScore = 60
                eventCount = 7
                minutes = 75
            default:
                avgScore = 45
                peakScore = 78
                eventCount = 14
                minutes = 100
            }
            
            days.append(DaySummary(
                date: date,
                averageScore: avgScore,
                peakScore: peakScore,
                eventCount: eventCount,
                totalMinutes: minutes
            ))
        }
        
        weekHistory = days
    }
    
    /// Generate 7 empty day entries for non-demo mode
    private func generateEmptyHistory() {
        let calendar = Calendar.current
        var days: [DaySummary] = []
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            days.append(DaySummary(
                date: date,
                averageScore: 0,
                peakScore: 0,
                eventCount: 0,
                totalMinutes: 0
            ))
        }
        
        weekHistory = days
    }
    
    private func updateTodayHistory(record: SessionRecord) {
        let calendar = Calendar.current
        if let index = weekHistory.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            let existing = weekHistory[index]
            weekHistory[index] = DaySummary(
                date: Date(),
                averageScore: existing.averageScore == 0
                    ? record.averageScore
                    : (existing.averageScore + record.averageScore) / 2,
                peakScore: max(existing.peakScore, record.peakScore),
                eventCount: existing.eventCount + record.eventCount,
                totalMinutes: existing.totalMinutes + record.endTime.timeIntervalSince(record.startTime) / 60
            )
        } else {
            // Today not in history yet — add it
            weekHistory.append(DaySummary(
                date: Date(),
                averageScore: record.averageScore,
                peakScore: record.peakScore,
                eventCount: record.eventCount,
                totalMinutes: record.endTime.timeIntervalSince(record.startTime) / 60
            ))
        }
    }
}
