import Foundation
import SwiftUI

// MARK: - Demo Manager

@MainActor
@Observable
final class DemoManager {
    
    /// Persisted demo mode toggle — defaults to true for judge experience
    var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode")
        }
    }
    
    init() {
        // Default to true (demo on) if never set
        if UserDefaults.standard.object(forKey: "isDemoMode") == nil {
            self.isDemoMode = true
        } else {
            self.isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
        }
    }
    
    // MARK: - Accelerated Time Simulation
    
    nonisolated(unsafe) private static let realStartTime = Date()
    private static let speedMultiplier: Double = 120.0 // 1 real second = 2 demo minutes
    
    /// Returns the current time. If demo mode is active, time moves 120x faster.
    var currentDate: Date {
        Self.sharedCurrentDate
    }
    
    /// Global accessor for non-View models like Engine to get the correct time
    static var sharedCurrentDate: Date {
        let isDemo = UserDefaults.standard.bool(forKey: "isDemoMode")
        if isDemo {
            let elapsedRealSeconds = Date().timeIntervalSince(realStartTime)
            let elapsedVirtualSeconds = elapsedRealSeconds * speedMultiplier
            return realStartTime.addingTimeInterval(elapsedVirtualSeconds)
        } else {
            return Date()
        }
    }
}
