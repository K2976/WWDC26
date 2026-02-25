import SwiftUI

// MARK: - Focus Orb View

struct FocusOrbView: View {
    let score: Double
    let size: CGFloat
    var isBreathingGuide: Bool = false
    var breathPhase: BreathPhase = .idle
    
    @State private var time: Double = 0
    
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
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            Canvas { context, canvasSize in
                let now = timeline.date.timeIntervalSinceReferenceDate
                drawOrb(context: context, size: canvasSize, time: now)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - Drawing
    
    private func drawOrb(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let normalizedScore = min(max(score, 0), 100) / 100.0
        
        // Base radius with score-based scaling
        let baseRadius = min(size.width, size.height) * 0.22
        let scoreScale = 1.0 + normalizedScore * 0.25
        
        // Score-driven pulse (existing behavior)
        let pulseSpeed = 0.5 + normalizedScore * 1.5
        let pulseAmount = 0.03 + normalizedScore * 0.07
        let scorePulse = sin(time * pulseSpeed * .pi) * pulseAmount
        
        // Ambient breathing — slow, organic, always-on (10s cycle, ~1.5% scale)
        let breathCycle = 10.0
        let breathPhaseVal = (time.truncatingRemainder(dividingBy: breathCycle)) / breathCycle
        // Smooth organic easing using combined sinusoids
        let breathEase = sin(breathPhaseVal * .pi * 2) * 0.5 + sin(breathPhaseVal * .pi * 4) * 0.15
        let ambientBreath = breathEase * 0.015
        
        let radius = baseRadius * scoreScale * (1.0 + scorePulse + ambientBreath)
        
        // Colors from existing score-reactive system
        let orbColor = FlowColors.color(for: score)
        let glowColor = FlowColors.glowColor(for: score)
        
        // Breathing-synced light intensity shift
        let breathLightShift = Float(breathEase * 0.08)
        
        // --- Layer 1: Atmospheric haze (outermost) ---
        let hazeRadius = radius * 1.8
        let hazePath = Path(ellipseIn: CGRect(
            x: center.x - hazeRadius,
            y: center.y - hazeRadius,
            width: hazeRadius * 2,
            height: hazeRadius * 2
        ))
        let hazeOpacity = 0.04 + Double(breathLightShift) * 0.5
        context.fill(hazePath, with: .radialGradient(
            Gradient(colors: [
                glowColor.opacity(hazeOpacity),
                glowColor.opacity(hazeOpacity * 0.4),
                glowColor.opacity(0)
            ]),
            center: center,
            startRadius: radius * 0.8,
            endRadius: hazeRadius
        ))
        
        // --- Layer 2: Soft outer glow (diffuse, no hard edges) ---
        let glowIntensity = 0.06 + normalizedScore * 0.12
        for i in stride(from: 3, through: 1, by: -1) {
            let glowRadius = radius * (1.0 + Double(i) * 0.12)
            let alpha = (glowIntensity / Double(i)) + Double(breathLightShift) * 0.3
            
            var glowPath: Path
            if normalizedScore > 0.7 {
                glowPath = distortedCircle(center: center, radius: glowRadius, time: time, intensity: normalizedScore)
            } else {
                glowPath = Path(ellipseIn: CGRect(
                    x: center.x - glowRadius,
                    y: center.y - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                ))
            }
            
            context.fill(glowPath, with: .color(glowColor.opacity(alpha)))
        }
        
        // --- Layer 3: Deep core (dark volumetric interior) ---
        let orbPath: Path
        if normalizedScore > 0.7 {
            orbPath = distortedCircle(center: center, radius: radius, time: time, intensity: normalizedScore)
        } else {
            orbPath = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        // Multi-stop gradient: dark dense core → color body → darker edge
        let coreGradient = Gradient(colors: [
            orbColor.opacity(0.5),           // Dense dark core
            orbColor.opacity(0.75),          // Mid transition
            orbColor,                         // Full color body
            orbColor.opacity(0.85),          // Slight fade
            orbColor.opacity(0.55)           // Darker limb
        ])
        
        // Offset light source to upper-left for 3D feel
        let lightOffset = CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.3)
        context.fill(orbPath, with: .radialGradient(
            coreGradient,
            center: lightOffset,
            startRadius: 0,
            endRadius: radius * 1.3
        ))
        
        // --- Layer 4: Subsurface scatter (faint internal glow, offset) ---
        let sssRadius = radius * 0.6
        let sssCenter = CGPoint(x: center.x - radius * 0.1, y: center.y - radius * 0.1)
        let sssPath = Path(ellipseIn: CGRect(
            x: sssCenter.x - sssRadius,
            y: sssCenter.y - sssRadius,
            width: sssRadius * 2,
            height: sssRadius * 2
        ))
        let sssOpacity = 0.06 + Double(breathLightShift) * 0.4
        context.fill(sssPath, with: .radialGradient(
            Gradient(colors: [
                .white.opacity(sssOpacity),
                .white.opacity(sssOpacity * 0.3),
                .clear
            ]),
            center: sssCenter,
            startRadius: 0,
            endRadius: sssRadius
        ))
        
        // --- Layer 5: Diffuse inner highlight (soft, large, no sharp specular) ---
        let highlightRadius = radius * 0.55
        let highlightCenter = CGPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.22)
        let highlightPath = Path(ellipseIn: CGRect(
            x: highlightCenter.x - highlightRadius,
            y: highlightCenter.y - highlightRadius,
            width: highlightRadius * 2,
            height: highlightRadius * 1.6
        ))
        let highlightOpacity = 0.04 + Double(breathLightShift) * 0.3 + scorePulse * 0.03
        context.fill(highlightPath, with: .radialGradient(
            Gradient(colors: [
                .white.opacity(highlightOpacity),
                .white.opacity(highlightOpacity * 0.2),
                .clear
            ]),
            center: highlightCenter,
            startRadius: 0,
            endRadius: highlightRadius
        ))
        
        // --- Layer 6: Rim light (thin crescent, upper-right) ---
        // Creates depth by separating orb from dark background
        let rimPath: Path
        if normalizedScore > 0.7 {
            rimPath = distortedCircle(center: center, radius: radius, time: time, intensity: normalizedScore)
        } else {
            rimPath = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        let rimLightCenter = CGPoint(x: center.x + radius * 0.6, y: center.y - radius * 0.5)
        let rimOpacity = 0.08 + Double(breathLightShift) * 0.4
        context.fill(rimPath, with: .radialGradient(
            Gradient(colors: [
                .white.opacity(rimOpacity),
                .white.opacity(rimOpacity * 0.3),
                .clear,
                .clear
            ]),
            center: rimLightCenter,
            startRadius: radius * 0.5,
            endRadius: radius * 1.1
        ))
        
        // --- Particles at high load (existing behavior) ---
        if normalizedScore > 0.6 {
            drawParticles(context: context, center: center, radius: radius, time: time, intensity: normalizedScore)
        }
    }
    
    // MARK: - Distortion
    
    private func distortedCircle(center: CGPoint, radius: Double, time: Double, intensity: Double) -> Path {
        var path = Path()
        let distortionAmount = (intensity - 0.7) * 15.0
        let segments = 64
        
        for i in 0...segments {
            let angle = (Double(i) / Double(segments)) * 2.0 * .pi
            
            let noise1 = sin(angle * 3 + time * 1.2) * distortionAmount
            let noise2 = sin(angle * 5 + time * 0.8) * distortionAmount * 0.5
            let noise3 = cos(angle * 7 + time * 1.5) * distortionAmount * 0.3
            
            let r = radius + noise1 + noise2 + noise3
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
    
    // MARK: - Particles
    
    private func drawParticles(context: GraphicsContext, center: CGPoint, radius: Double, time: Double, intensity: Double) {
        let particleCount = Int((intensity - 0.6) * 25)
        let color = FlowColors.color(for: score)
        
        for i in 0..<particleCount {
            let seed = Double(i) * 2.399
            let particleTime = time * 0.3 + seed
            
            let angle = seed + particleTime * 0.5
            let distance = radius * (1.1 + (sin(particleTime * 0.7) + 1) * 0.4)
            
            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance
            
            let particleSize = 2.0 + sin(particleTime * 2) * 1.5
            let alpha = max(0, 0.6 - (distance - radius) / (radius * 0.8))
            
            let particlePath = Path(ellipseIn: CGRect(
                x: x - particleSize / 2,
                y: y - particleSize / 2,
                width: particleSize,
                height: particleSize
            ))
            
            context.fill(particlePath, with: .color(color.opacity(alpha)))
        }
    }
}
