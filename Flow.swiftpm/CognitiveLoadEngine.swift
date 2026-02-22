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
    
    var sessionStartTime: Date = Date()
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
            timestamp: Date(),
            scoreAfter: score
        )
        events.append(record)
    }
    
    func setScore(_ newScore: Double) {
        score = min(max(newScore, 0), 100)
        state = CognitiveState.from(score: score)
        scoreHistory.append(score)
    }
    
    func setInitialScore(_ value: Double) {
        score = min(max(value, 0), 100)
        animatedScore = score
        state = CognitiveState.from(score: score)
        sessionStartScore = score
        sessionStartTime = Date()
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
        resetTimestamps.append(Date())
    }
    
    func resetSession() {
        events.removeAll()
        history.removeAll()
        scoreHistory.removeAll()
        resetTimestamps.removeAll()
        score = 20.0
        animatedScore = 20.0
        state = CognitiveState.from(score: score)
        sessionStartTime = Date()
        sessionStartScore = score
        takeSnapshot()
    }
    
    func buildSessionRecord() -> SessionRecord {
        let avg = scoreHistory.isEmpty ? score : scoreHistory.reduce(0, +) / Double(scoreHistory.count)
        let peak = scoreHistory.max() ?? score
        return SessionRecord(
            startTime: sessionStartTime,
            endTime: Date(),
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
        
        // Animated score interpolation
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
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
        let snapshot = LoadSnapshot(timestamp: Date(), score: score)
        history.append(snapshot)
        
        // Keep last 20 minutes of data (120 snapshots at 10s intervals)
        let cutoff = Date().addingTimeInterval(-20 * 60)
        history = history.filter { $0.timestamp > cutoff }
    }
    
    private func updateAnimatedScore() {
        let diff = score - animatedScore
        if abs(diff) < 0.1 {
            animatedScore = score
        } else {
            animatedScore += diff * 0.15
        }
    }
}
