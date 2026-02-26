import SwiftUI
import SceneKit

// MARK: - Focus Orb View
// Public API preserved for DashboardView compatibility.
// Renders a true 3D interactive globe via SceneKit.

struct FocusOrbView: View {
    let score: Double
    let size: CGFloat
    var isBreathingGuide: Bool = false
    var breathPhase: BreathPhase = .idle

    enum BreathPhase {
        case idle, breatheIn, hold, breatheOut
        var label: String {
            switch self {
            case .idle: return ""
            case .breatheIn: return "Breathe In"
            case .hold: return "Hold"
            case .breatheOut: return "Breathe Out"
            }
        }
    }

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            let minDuration: Double = 0.25 // Extremely fast heartbeat at max
            let duration: Double = max(2.5 - (score / 100.0) * 2.25, minDuration)
            
            let maxScale: CGFloat = 1.05 + CGFloat(score / 100.0) * 0.25
            let minScale: CGFloat = 0.9 - CGFloat(score / 100.0) * 0.05
            
            let minBlur: CGFloat = size * 0.20
            let maxBlur: CGFloat = size * 0.60
            let currentBlur: CGFloat = minBlur + (maxBlur - minBlur) * CGFloat(score / 100.0)
            
            // TimelineView completely detaches the animation cycle from view-reloads, ensuring it NEVER stops
            TimelineView(.animation) { context in
                DynamicPulseView(
                    date: context.date,
                    duration: duration,
                    score: score,
                    size: size,
                    minBlur: currentBlur,
                    minScale: minScale,
                    maxScale: maxScale
                )
            }
            
            GlobeSceneView(score: score)
                // Render larger so the sphere never clips at the square edge.
                .frame(width: size * 1.3, height: size * 1.3)
                .padding(-size * 0.15)
        }
    }
}

// MARK: - Dynamic Pulse View
// Handles accumulated phase for a perfectly smooth sine wave, even when `duration` changes abruptly.
struct DynamicPulseView: View {
    let date: Date
    let duration: Double
    let score: Double
    let size: CGFloat
    let minBlur: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    
    @State private var accumulatedPhase: Double = 0
    @State private var lastUpdate: Date = Date()
    
    var body: some View {
        // Calculate the smooth 0-1 sine wave value based on accumulated phase
        let value = (sin(accumulatedPhase) + 1) / 2
        
        Circle()
            .fill(FlowColors.glowColor(for: score))
            .frame(width: size * 0.95, height: size * 0.95)
            .blur(radius: minBlur)
            .scaleEffect(minScale + (maxScale - minScale) * value)
            .opacity(0.4 + 0.55 * value)
            .onChange(of: date) { _, newDate in
                let dt = newDate.timeIntervalSince(lastUpdate)
                lastUpdate = newDate
                
                // Add to phase based on current duration speed
                // 2 * pi represents one full heartbeat cycle.
                let phaseIncrement = (dt / duration) * .pi * 2
                accumulatedPhase += phaseIncrement
                
                // Keep phase bounded to prevent precision loss over long sessions
                if accumulatedPhase > .pi * 2000 {
                    accumulatedPhase -= .pi * 2000
                }
            }
            .onAppear {
                lastUpdate = date
            }
    }
}
