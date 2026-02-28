import SwiftUI

// MARK: - Cognitive State

enum CognitiveState: String, CaseIterable {
    case calm, focused, moderate, high, overloaded
    
    var label: String {
        switch self {
        case .calm: return "Calm"
        case .focused: return "In Flow"
        case .moderate: return "Busy"
        case .high: return "Scattered"
        case .overloaded: return "Overloaded"
        }
    }
    
    var contextualLine: String {
        switch self {
        case .calm: return "Your mind is still. Stay here."
        case .focused: return "You're in the zone. Protect this."
        case .moderate: return "Attention is splitting. Notice it."
        case .high: return "Too many threads. Time to slow down."
        case .overloaded: return "Your mind needs a moment. Let go."
        }
    }
    
    var scoreRange: ClosedRange<Double> {
        switch self {
        case .calm: return 0...25
        case .focused: return 26...50
        case .moderate: return 51...70
        case .high: return 71...85
        case .overloaded: return 86...100
        }
    }
    
    static func from(score: Double) -> CognitiveState {
        switch score {
        case 0...25: return .calm
        case 26...50: return .focused
        case 51...70: return .moderate
        case 71...85: return .high
        default: return .overloaded
        }
    }
}

// MARK: - Flow Colors

struct FlowColors {
    
    /// Returns an interpolated color based on cognitive load score (0–100)
    /// Uses HSB perceptual interpolation for smooth transitions
    static func color(for score: Double) -> Color {
        let clamped = min(max(score, 0), 100)
        
        // Color stops: (score, hue, saturation, brightness)
        // Teal → Cyan → Green → Yellow → Orange → Red
        let stops: [(Double, Double, Double, Double)] = [
            (0,   0.52, 0.75, 0.85),   // Teal
            (20,  0.48, 0.70, 0.80),   // Cyan
            (40,  0.35, 0.65, 0.75),   // Green
            (55,  0.15, 0.75, 0.85),   // Yellow
            (70,  0.08, 0.80, 0.90),   // Orange
            (85,  0.02, 0.85, 0.85),   // Red-orange
            (100, 0.00, 0.90, 0.75),   // Deep red
        ]
        
        // Find surrounding stops
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        
        for i in 0..<stops.count - 1 {
            if clamped >= stops[i].0 && clamped <= stops[i + 1].0 {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        
        let range = upper.0 - lower.0
        let t = range > 0 ? (clamped - lower.0) / range : 0
        
        // Smooth interpolation using ease-in-out
        let smoothT = t * t * (3 - 2 * t)
        
        let h = lower.1 + (upper.1 - lower.1) * smoothT
        let s = lower.2 + (upper.2 - lower.2) * smoothT
        let b = lower.3 + (upper.3 - lower.3) * smoothT
        
        return Color(hue: h, saturation: s, brightness: b)
    }
    
    /// Pastel color — lower saturation, high brightness for vibrant fill
    static func pastelColor(for score: Double) -> Color {
        let clamped = min(max(score, 0), 100)
        // Pastel stops: lower saturation, higher brightness than base
        let stops: [(Double, Double, Double, Double)] = [
            (0,   0.52, 0.45, 0.82),   // Soft teal
            (20,  0.48, 0.42, 0.82),   // Soft cyan
            (40,  0.35, 0.42, 0.80),   // Soft green
            (55,  0.15, 0.50, 0.88),   // Soft yellow
            (70,  0.08, 0.55, 0.92),   // Soft orange
            (85,  0.02, 0.55, 0.88),   // Soft red-orange
            (100, 0.00, 0.60, 0.82),   // Soft red
        ]
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for i in 0..<stops.count - 1 {
            if clamped >= stops[i].0 && clamped <= stops[i + 1].0 {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        let range = upper.0 - lower.0
        let t = range > 0 ? (clamped - lower.0) / range : 0
        let smoothT = t * t * (3 - 2 * t)
        let h = lower.1 + (upper.1 - lower.1) * smoothT
        let s = lower.2 + (upper.2 - lower.2) * smoothT
        let b = lower.3 + (upper.3 - lower.3) * smoothT
        return Color(hue: h, saturation: s, brightness: b)
    }
    
    /// Glow color — brighter, more saturated version
    static func glowColor(for score: Double) -> Color {
        let clamped = min(max(score, 0), 100)
        let base = color(for: clamped)
        return base.opacity(0.6 + (clamped / 100.0) * 0.4)
    }
    
    /// Background color — dark but with noticeable tint matching the orb
    static func backgroundColor(for score: Double) -> Color {
        let clamped = min(max(score, 0), 100)
        // Matches the orb color hues but very dark
        let stops: [(Double, Double, Double, Double)] = [
            (0,   0.52, 0.30, 0.12),   // Teal tint
            (25,  0.48, 0.30, 0.12),   // Cyan tint
            (45,  0.35, 0.30, 0.12),   // Green tint
            (60,  0.15, 0.35, 0.13),   // Yellow tint
            (75,  0.08, 0.40, 0.14),   // Orange tint
            (90,  0.02, 0.45, 0.14),   // Red-orange tint
            (100, 0.00, 0.45, 0.13),   // Dark red tint
        ]
        
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for i in 0..<stops.count - 1 {
            if clamped >= stops[i].0 && clamped <= stops[i + 1].0 {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        let range = upper.0 - lower.0
        let t = range > 0 ? (clamped - lower.0) / range : 0
        let smoothT = t * t * (3 - 2 * t)
        return Color(hue: lower.1 + (upper.1 - lower.1) * smoothT,
                     saturation: lower.2 + (upper.2 - lower.2) * smoothT,
                     brightness: lower.3 + (upper.3 - lower.3) * smoothT)
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {

    // Fixed star positions computed once (seed-based LCG — no random per render)
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, a: CGFloat)] = {
        var seed: UInt64 = 0xDEADBEEF_CAFEBABE
        func rand() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(Int32.max)
        }
        return (0..<320).map { _ in
            (rand(), rand(), 0.6 + rand() * 1.8, 0.15 + rand() * 0.65)
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Deep space base
                Color(hue: 0.62, saturation: 0.12, brightness: 0.04)

                // Star field — static, very low contrast
                Canvas { ctx, size in
                    for star in Self.stars {
                        let pt = CGPoint(x: star.x * size.width, y: star.y * size.height)
                        let path = Path(ellipseIn: CGRect(x: pt.x, y: pt.y,
                                                          width: star.r, height: star.r))
                        ctx.fill(path, with: .color(.white.opacity(star.a * 0.55)))
                    }
                }

                // Radial vignette toward edges
                RadialGradient(
                    colors: [.clear, .black.opacity(0.45), .black.opacity(0.75)],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.28,
                    endRadius:   max(geo.size.width, geo.size.height) * 0.72
                )
            }
        }
        .ignoresSafeArea()
    }
}


// MARK: - Typography

struct FlowTypography {
    static func scoreFont(size: CGFloat = 64) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    
    static func labelFont(size: CGFloat = 18) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    
    static func bodyFont(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    
    static func captionFont(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    
    static func headingFont(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Animation Constants

struct FlowAnimation {
    static let colorTransition: Animation = .easeInOut(duration: 1.8)
    static let orbPulse: Animation = .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let scoreChange: Animation = .spring(response: 0.6, dampingFraction: 0.8)
    static let viewTransition: Animation = .easeInOut(duration: 0.5)
    static let breatheIn: Double = 4.0
    static let breatheHold: Double = 7.0
    static let breatheOut: Double = 8.0
}
