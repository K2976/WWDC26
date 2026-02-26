import Foundation
import SwiftUI
import Combine

// MARK: - Cognitive Load Engine

@MainActor
@Observable
final class CognitiveLoadEngine {
    
    // MARK: - Published State
    
    private(set) var score: Double = 20.0
    private(set) var state: CognitiveState = .calm
    private(set) var history: [LoadSnapshot] = []
    private(set) var events: [AttentionEventRecord] = []
    private(set) var animatedScore: Double = 20.0
    private(set) var resetTimestamps: [Date] = []
    
    var isFocusMode: Bool = false {
        didSet { updateDecayRate() }
    }
    
    // MARK: - Internal
    
    private var decayTimer: Timer?
    private var snapshotTimer: Timer?
    private var animationTimer: Timer?
    private let decayAmount: Double = 3.0
    private let focusDecayMultiplier: Double = 2.0
    private var normalDecayInterval: TimeInterval = 30.0
    private var sessionStartScore: Double = 20.0
    
    var sessionStartTime: Date = DemoManager.sharedCurrentDate
    var scoreHistory: [Double] = []
    
    // MARK: - Init
    
    init() {
        startTimers()
    }
    
    // MARK: - Public API
    
    func logEvent(_ event: AttentionEvent) {
        let newScore = min(score + event.loadIncrease, 100)
        setScore(newScore)
        
        let record = AttentionEventRecord(
            event: event,
            timestamp: DemoManager.sharedCurrentDate,
            scoreAfter: score
        )
        events.append(record)
        
        // Keep events bounded
        if events.count > 50 {
            events.removeFirst(events.count - 50)
        }
    }
    
    func setScore(_ newScore: Double) {
        let clamped = min(max(newScore, 0), 100)
        score = clamped
        let newState = CognitiveState.from(score: clamped)
        if newState != state {
            state = newState
        }
        scoreHistory.append(clamped)
    }
    
    func setInitialScore(_ value: Double) {
        score = min(max(value, 0), 100)
        animatedScore = score
        state = CognitiveState.from(score: score)
        sessionStartScore = score
        sessionStartTime = DemoManager.sharedCurrentDate
        takeSnapshot()
    }
    
    func triggerAcceleratedDecay(amount: Double = 20, duration: TimeInterval = 10) {
        let steps = 20
        let decayPerStep = amount / Double(steps)
        let interval = duration / Double(steps)
        
        func scheduleStep(_ currentStep: Int) {
            guard currentStep < steps else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                self?.setScore((self?.score ?? 0) - decayPerStep)
                scheduleStep(currentStep + 1)
            }
        }
        scheduleStep(0)
    }
    
    func markReset() {
        resetTimestamps.append(DemoManager.sharedCurrentDate)
    }
    
    func resetSession() {
        events.removeAll()
        history.removeAll()
        scoreHistory.removeAll()
        resetTimestamps.removeAll()
        score = 20.0
        animatedScore = 20.0
        state = CognitiveState.from(score: score)
        sessionStartTime = DemoManager.sharedCurrentDate
        sessionStartScore = score
        takeSnapshot()
    }
    
    func buildSessionRecord() -> SessionRecord {
        let avg = scoreHistory.isEmpty ? score : scoreHistory.reduce(0, +) / Double(scoreHistory.count)
        let peak = scoreHistory.max() ?? score
        return SessionRecord(
            startTime: sessionStartTime,
            endTime: DemoManager.sharedCurrentDate,
            startScore: sessionStartScore,
            endScore: score,
            averageScore: avg,
            peakScore: peak,
            eventCount: events.count,
            events: events
        )
    }
    
    // MARK: - Timers
    
    private func startTimers() {
        // Decay timer
        updateDecayRate()
        
        // Snapshot timer — every 10 seconds
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.takeSnapshot()
            }
        }
        takeSnapshot()
        
        // Animated score interpolation — 10fps is enough since the orb has its own 60fps Canvas
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimatedScore()
            }
        }
    }
    
    private func updateDecayRate() {
        decayTimer?.invalidate()
        let interval = isFocusMode ? normalDecayInterval / focusDecayMultiplier : normalDecayInterval
        decayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.decay()
            }
        }
    }
    
    private func decay() {
        let amount = isFocusMode ? decayAmount * focusDecayMultiplier : decayAmount
        setScore(score - amount)
    }
    
    private func takeSnapshot() {
        let snapshot = LoadSnapshot(timestamp: DemoManager.sharedCurrentDate, score: score)
        history.append(snapshot)
        
        // Keep last 20 minutes of data (120 snapshots at 10s intervals)
        let cutoff = DemoManager.sharedCurrentDate.addingTimeInterval(-20 * 60)
        history = history.filter { $0.timestamp > cutoff }
    }
    
    private func updateAnimatedScore() {
        let diff = score - animatedScore
        if abs(diff) < 0.5 {
            // Only update if actually different to avoid triggering @Observable
            if animatedScore != score {
                animatedScore = score
            }
        } else {
            animatedScore += diff * 0.15
        }
    }
}
