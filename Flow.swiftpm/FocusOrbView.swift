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
    
    // MARK: - Main Drawing
    
    private func drawOrb(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let normalizedScore = min(max(score, 0), 100) / 100.0
        
        // Base radius with score-based scaling
        let baseRadius = min(size.width, size.height) * 0.24
        let scoreScale = 1.0 + normalizedScore * 0.2
        
        // Score-driven pulse
        let pulseSpeed = 0.5 + normalizedScore * 1.5
        let pulseAmount = 0.03 + normalizedScore * 0.07
        let scorePulse = sin(time * pulseSpeed * .pi) * pulseAmount
        
        // Ambient breathing (10s cycle, ~1.5%)
        let breathCycle = 10.0
        let breathPhaseVal = (time.truncatingRemainder(dividingBy: breathCycle)) / breathCycle
        let breathEase = sin(breathPhaseVal * .pi * 2) * 0.5 + sin(breathPhaseVal * .pi * 4) * 0.15
        let ambientBreath = breathEase * 0.015
        
        let radius = baseRadius * scoreScale * (1.0 + scorePulse + ambientBreath)
        
        // Score-reactive colors
        let orbColor = FlowColors.color(for: score)
        let glowColor = FlowColors.glowColor(for: score)
        
        // Slow rotation angle (45s full revolution)
        let rotationAngle = time * (.pi * 2 / 45.0)
        let breathLight = breathEase * 0.06
        
        // === LAYER 1: Atmospheric glow (outermost) ===
        drawAtmosphere(context: context, center: center, radius: radius, color: glowColor, breathLight: breathLight)
        
        // === LAYER 2: Base sphere with limb darkening ===
        let sphereRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let spherePath: Path
        if normalizedScore > 0.7 {
            spherePath = distortedCircle(center: center, radius: radius, time: time, intensity: normalizedScore)
        } else {
            spherePath = Path(ellipseIn: sphereRect)
        }
        
        // Dark base fill
        context.fill(spherePath, with: .color(orbColor.opacity(0.25)))
        
        // === Draw all sphere-interior layers in a clipped layer ===
        context.drawLayer { innerCtx in
            innerCtx.clip(to: spherePath)
            
            // === LAYER 3: Surface bands that rotate (visible rotation) ===
            drawSurfaceBands(context: innerCtx, center: center, radius: radius, time: time, rotationAngle: rotationAngle, color: orbColor)
            
            // === LAYER 4: Directional lighting (terminator - 3D illusion) ===
            let lightAngle = rotationAngle * 0.1
            let lightX = center.x + cos(lightAngle - .pi * 0.7) * radius * 0.5
            let lightY = center.y + sin(lightAngle - .pi * 0.7) * radius * 0.5
            let lightCenter = CGPoint(x: lightX, y: lightY)
            
            innerCtx.fill(spherePath, with: .radialGradient(
                Gradient(colors: [
                    orbColor.opacity(0.9 + breathLight),
                    orbColor.opacity(0.7),
                    orbColor.opacity(0.3),
                    orbColor.opacity(0.05)
                ]),
                center: lightCenter,
                startRadius: 0,
                endRadius: radius * 1.6
            ))
            
            // === LAYER 5: Limb darkening ===
            innerCtx.fill(spherePath, with: .radialGradient(
                Gradient(colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.2),
                    .black.opacity(0.6)
                ]),
                center: center,
                startRadius: radius * 0.3,
                endRadius: radius
            ))
            
            // === LAYER 6: Subsurface scatter ===
            let sssOffset = CGPoint(
                x: center.x + cos(rotationAngle * 0.3) * radius * 0.15,
                y: center.y + sin(rotationAngle * 0.3) * radius * 0.1
            )
            innerCtx.fill(spherePath, with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.06 + breathLight * 0.5),
                    .white.opacity(0.02),
                    .clear
                ]),
                center: sssOffset,
                startRadius: 0,
                endRadius: radius * 0.6
            ))
            
            // === LAYER 7: Specular highlight ===
            let specX = center.x + cos(lightAngle - .pi * 0.7) * radius * 0.35
            let specY = center.y + sin(lightAngle - .pi * 0.7) * radius * 0.35
            let specCenter = CGPoint(x: specX, y: specY)
            let specRadius = radius * 0.35
            let specPath = Path(ellipseIn: CGRect(
                x: specCenter.x - specRadius,
                y: specCenter.y - specRadius * 0.7,
                width: specRadius * 2,
                height: specRadius * 1.4
            ))
            innerCtx.fill(specPath, with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.12 + breathLight * 0.4),
                    .white.opacity(0.04),
                    .clear
                ]),
                center: specCenter,
                startRadius: 0,
                endRadius: specRadius
            ))
            
            // === LAYER 8: Rim light ===
            let rimCenter = CGPoint(
                x: center.x + cos(lightAngle - .pi * 0.7 + .pi) * radius * 0.7,
                y: center.y + sin(lightAngle - .pi * 0.7 + .pi) * radius * 0.5
            )
            innerCtx.fill(spherePath, with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.1 + breathLight * 0.3),
                    .white.opacity(0.03),
                    .clear,
                    .clear
                ]),
                center: rimCenter,
                startRadius: radius * 0.6,
                endRadius: radius * 1.05
            ))
        }
        
        // Particles at high load
        if normalizedScore > 0.6 {
            drawParticles(context: context, center: center, radius: radius, time: time, intensity: normalizedScore)
        }
    }
    
    // MARK: - Atmosphere
    
    private func drawAtmosphere(context: GraphicsContext, center: CGPoint, radius: Double, color: Color, breathLight: Double) {
        // Outer atmospheric haze
        for i in stride(from: 3, through: 1, by: -1) {
            let hazeRadius = radius * (1.0 + Double(i) * 0.15)
            let alpha = (0.04 + breathLight * 0.3) / Double(i)
            let hazePath = Path(ellipseIn: CGRect(
                x: center.x - hazeRadius,
                y: center.y - hazeRadius,
                width: hazeRadius * 2,
                height: hazeRadius * 2
            ))
            context.fill(hazePath, with: .color(color.opacity(alpha)))
        }
    }
    
    // MARK: - Surface Bands (Rotating Features)
    
    private func drawSurfaceBands(context: GraphicsContext, center: CGPoint, radius: Double, time: Double, rotationAngle: Double, color: Color) {
        // Draw multiple horizontal bands at different latitudes
        // These scroll horizontally to create the illusion of planetary rotation
        let bandConfigs: [(latitude: Double, width: Double, opacity: Double, speed: Double)] = [
            (-0.6,  0.08, 0.12, 1.0),
            (-0.35, 0.12, 0.08, 1.0),
            (-0.1,  0.15, 0.10, 1.0),
            ( 0.15, 0.10, 0.07, 1.0),
            ( 0.35, 0.18, 0.09, 1.0),
            ( 0.55, 0.06, 0.11, 1.0),
            (-0.45, 0.05, 0.06, 0.8),
            ( 0.0,  0.20, 0.05, 1.2),
            ( 0.5,  0.08, 0.08, 0.9),
        ]
        
        for band in bandConfigs {
            let lat = band.latitude
            // Spherical projection: band width compresses at poles
            let latFactor = sqrt(max(0.01, 1.0 - lat * lat))
            let bandHalfWidth = radius * latFactor
            
            let yPos = center.y + lat * radius * 0.85
            let bandHeight = radius * band.width * latFactor
            
            // Horizontal scroll from rotation
            let scrollOffset = cos(rotationAngle * band.speed + lat * 2.0) * radius * 0.3
            
            // Draw band as an elongated ellipse
            let bandRect = CGRect(
                x: center.x - bandHalfWidth + scrollOffset,
                y: yPos - bandHeight / 2,
                width: bandHalfWidth * 2,
                height: bandHeight
            )
            
            // Slightly brighter version of the orb color for bands
            let bandPath = Path(ellipseIn: bandRect)
            context.fill(bandPath, with: .color(color.opacity(band.opacity)))
        }
        
        // Add a couple of "storm" spots that rotate
        let stormCount = 2
        for i in 0..<stormCount {
            let stormLat = (Double(i) * 0.5 - 0.25)
            let latFactor = sqrt(max(0.01, 1.0 - stormLat * stormLat))
            
            // Storm orbits around the equator
            let stormAngle = rotationAngle + Double(i) * .pi
            let stormX = center.x + cos(stormAngle) * radius * 0.4 * latFactor
            let stormY = center.y + stormLat * radius * 0.85
            
            // Only draw when on the visible hemisphere (cos > 0 means facing us)
            let visibility = max(0, cos(stormAngle))
            if visibility > 0.1 {
                let stormSize = radius * 0.12 * latFactor
                let stormPath = Path(ellipseIn: CGRect(
                    x: stormX - stormSize,
                    y: stormY - stormSize * 0.6,
                    width: stormSize * 2,
                    height: stormSize * 1.2
                ))
                context.fill(stormPath, with: .color(color.opacity(0.15 * visibility)))
            }
        }
    }
    
    // MARK: - Distortion (High Load)
    
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
    
    // MARK: - Particles (High Load)
    
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
