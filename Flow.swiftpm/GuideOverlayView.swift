import SwiftUI

// MARK: - Reverse Mask (transparent cutout in overlay)

private extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay {
                    mask()
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}

// MARK: - Highlight Specification

private struct HighlightSpec {
    let center: CGPoint
    let size: CGSize
    let isCircle: Bool
    let cardPosition: CGPoint
}

// MARK: - Guide Overlay View

struct GuideOverlayView: View {
    let engine: CognitiveLoadEngine
    let demoManager: DemoManager
    let s: CGFloat
    let dismiss: () -> Void
    
    @State private var currentStep = 0
    @State private var cardVisible = false
    @State private var spotlightVisible = false
    @State private var ringPulse = false
    
    private let totalSteps = 10
    
    // Guide content for each step
    private var steps: [(index: Int, label: String, desc: String, note: String?, hasIcon: Bool)] {
        [
            (1, "YOUR MIND, VISUALIZED",
             "This 3D globe represents your cognitive load in real time. Color shifts from calm teal to stressed red as your attention fragments. Drag it to spin.",
             nil, false),
            (2, "COGNITIVE LOAD SCORE",
             "0 is fully focused. 100 is overloaded. Score rises with distractions and decays naturally over time. The arrow shows current direction.",
             nil, false),
            (3, "SESSION CLOCK",
             demoManager.isDemoMode
                ? "Running at 120× speed — shows a full day of attention patterns in minutes so you can see Flow's full range."
                : "Current time. Tracks your focus session from when you set your attention level.",
             demoManager.isDemoMode ? "120× demo speed" : nil, false),
            (4, "SESSION DURATION",
             "Total time in your current focus session. Resets when you start a new one.",
             nil, false),
            (5, "DO NOT DISTURB",
             "Toggles macOS Do Not Disturb so notifications don't break your flow. One tap silences everything — another brings them back.",
             nil, false),
            (6, "BINAURAL BEATS",
             "Flow generates real-time procedural audio — layered binaural beats that shift frequency with your cognitive load. Low scores play calming alpha waves; high scores introduce grounding theta pulses to ease you back.",
             "Wear headphones for full effect", false),
            (7, "RESET",
             "Guides your cognitive load score smoothly back to baseline. Use it after a break or context switch to start fresh without ending the session.",
             nil, false),
            (8, "ANALYTICS PANEL",
             "Opens your attention timeline, 7-day history, and neuroscience insights about what's happening to your focus.",
             nil, false),
            (9, demoManager.isDemoMode ? "DEMO CONTROLS" : "SESSION CONTROLS",
             demoManager.isDemoMode
                ? "DEMO is auto-simulating distractions so you can see Flow react in real time. END closes this session and shows your full attention summary."
                : "Flow is tracking real app switches and idle time via macOS system events. END closes the session and shows your stats.",
             demoManager.isDemoMode ? "Auto-simulation active" : "Live system tracking active", false),
            (10, "MENU BAR COMPANION",
             "A mini orb lives in your macOS menu bar at all times. Click it to check your score or log events without switching windows.",
             nil, true),
        ]
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let color = FlowColors.color(for: engine.animatedScore)
            let spec = currentStep < totalSteps
                ? highlightSpec(for: steps[currentStep].index, w: w, h: h)
                : highlightSpec(for: 1, w: w, h: h)
            let cutoutW = spec.size.width + 20 * s
            let cutoutH = spec.size.height + 20 * s
            
            ZStack {
                // 1. Dark overlay with transparent cutout
                Color.black.opacity(0.85)
                    .overlay {
                        Group {
                            if spec.isCircle {
                                Circle()
                                    .frame(width: cutoutW, height: cutoutH)
                            } else {
                                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                                    .frame(width: cutoutW, height: cutoutH)
                            }
                        }
                        .position(x: spec.center.x, y: spec.center.y)
                        .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .ignoresSafeArea()
                    .onTapGesture { advance() }
                
                // 2. Glowing highlight ring around the feature
                Group {
                    if spec.isCircle {
                        Circle()
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                            .frame(width: cutoutW, height: cutoutH)
                    } else {
                        RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                            .frame(width: cutoutW, height: cutoutH)
                    }
                }
                .shadow(color: color.opacity(0.4), radius: 10)
                .shadow(color: color.opacity(0.2), radius: 24)
                .scaleEffect(ringPulse ? 1.03 : 1.0)
                .opacity(ringPulse ? 0.7 : 1.0)
                .position(x: spec.center.x, y: spec.center.y)
                .opacity(spotlightVisible ? 1 : 0)
                .allowsHitTesting(false)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: ringPulse
                )
                
                // 3. Guide card positioned near the feature
                if currentStep < totalSteps {
                    let step = steps[currentStep]
                    GuideCard(
                        index: step.index,
                        label: step.label,
                        desc: step.desc,
                        note: step.note,
                        hasIcon: step.hasIcon,
                        isVisible: $cardVisible,
                        s: s,
                        engine: engine
                    )
                    .position(x: spec.cardPosition.x, y: spec.cardPosition.y)
                    .transition(.opacity)
                }
                
                // 4. Navigation row
                VStack {
                    Spacer()
                    HStack(spacing: 16 * s) {
                        HStack(spacing: 6 * s) {
                            ForEach(0..<totalSteps, id: \.self) { i in
                                Circle()
                                    .fill(i == currentStep
                                          ? color
                                          : .white.opacity(i < currentStep ? 0.3 : 0.12))
                                    .frame(width: 6 * s, height: 6 * s)
                            }
                        }
                        
                        Spacer()
                        
                        Button { advance() } label: {
                            Capsule()
                                .fill(color.opacity(0.25))
                                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
                                .frame(width: 120 * s, height: 40 * s)
                                .overlay(
                                    Text(currentStep < totalSteps - 1 ? "Next  →" : "Got it  ✓")
                                        .font(.system(size: 14 * s, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 32 * s)
                    .padding(.bottom, 36 * s)
                }
            }
        }
        .onAppear { showStep() }
    }
    
    // MARK: - Step Navigation
    
    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeOut(duration: 0.2)) {
                cardVisible = false
                spotlightVisible = false
                ringPulse = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                currentStep += 1
                showStep()
            }
        } else {
            dismiss()
        }
    }
    
    private func showStep() {
        ringPulse = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            cardVisible = true
            spotlightVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ringPulse = true
        }
    }
    
    // MARK: - Highlight Positions
    
    private func highlightSpec(for index: Int, w: CGFloat, h: CGFloat) -> HighlightSpec {
        let pad: CGFloat = 28 * s
        let cardHalfW: CGFloat = 100 * s   // card is 200*s wide
        let cardHalfH: CGFloat = 65 * s    // estimated half-height of card
        let gap: CGFloat = 16 * s          // gap between feature and card
        
        // Clamp card X so it doesn't go off screen
        func clampX(_ x: CGFloat) -> CGFloat {
            max(pad + cardHalfW, min(w - pad - cardHalfW, x))
        }
        
        // Top features: y center of top control row
        let topY: CGFloat = 54 * s
        // Bottom features: y center of bottom control row
        let btnY: CGFloat = h - 38 * s
        
        switch index {
        case 1: // Orb — center
            let orbSize = min(max(min(w, h) * 0.52, 180), 700)
            let orbCY = h / 2 - 30 * s
            return HighlightSpec(
                center: CGPoint(x: w / 2, y: orbCY),
                size: CGSize(width: orbSize, height: orbSize),
                isCircle: true,
                cardPosition: CGPoint(
                    x: w / 2,
                    y: orbCY + orbSize / 2 + gap + cardHalfH + 30 * s
                )
            )
            
        case 2: // Score — top center
            return HighlightSpec(
                center: CGPoint(x: w / 2, y: topY),
                size: CGSize(width: 140 * s, height: 90 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: w / 2,
                    y: topY + 45 * s + gap + cardHalfH
                )
            )
            
        case 3: // Clock — top left
            let clockX = pad + 105 * s
            return HighlightSpec(
                center: CGPoint(x: clockX, y: topY),
                size: CGSize(width: 220 * s, height: 76 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(clockX),
                    y: topY + 38 * s + gap + cardHalfH
                )
            )
            
        case 4: // Session duration — top right
            let durX = w - pad - 85 * s
            return HighlightSpec(
                center: CGPoint(x: durX, y: topY),
                size: CGSize(width: 170 * s, height: 90 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(durX),
                    y: topY + 45 * s + gap + cardHalfH
                )
            )
            
        case 5: // DND — bottom left, first button
            let dndX = pad + 47 * s
            return HighlightSpec(
                center: CGPoint(x: dndX, y: btnY),
                size: CGSize(width: 95 * s, height: 44 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(dndX),
                    y: btnY - 22 * s - gap - cardHalfH
                )
            )
            
        case 6: // Sound (Binaural Beats) — bottom left, second button
            let sndX = pad + 146 * s
            return HighlightSpec(
                center: CGPoint(x: sndX, y: btnY),
                size: CGSize(width: 88 * s, height: 44 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(sndX),
                    y: btnY - 22 * s - gap - cardHalfH
                )
            )
            
        case 7: // Reset — bottom left, third button
            let rstX = pad + 252 * s
            return HighlightSpec(
                center: CGPoint(x: rstX, y: btnY),
                size: CGSize(width: 110 * s, height: 44 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(rstX),
                    y: btnY - 22 * s - gap - cardHalfH
                )
            )
            
        case 8: // Analytics chevron — bottom center
            return HighlightSpec(
                center: CGPoint(x: w / 2, y: btnY),
                size: CGSize(width: 44 * s, height: 44 * s),
                isCircle: true,
                cardPosition: CGPoint(
                    x: w / 2,
                    y: btnY - 22 * s - gap - cardHalfH
                )
            )
            
        case 9: // Demo / End — bottom right
            let grpW: CGFloat = 160 * s
            let grpX = w - pad - grpW / 2
            return HighlightSpec(
                center: CGPoint(x: grpX, y: btnY),
                size: CGSize(width: grpW + 10 * s, height: 44 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(grpX),
                    y: btnY - 22 * s - gap - cardHalfH
                )
            )
            
        case 10: // Menu bar — top right edge
            let mbX = w - 60 * s
            let mbY: CGFloat = 14 * s
            return HighlightSpec(
                center: CGPoint(x: mbX, y: mbY),
                size: CGSize(width: 44 * s, height: 28 * s),
                isCircle: false,
                cardPosition: CGPoint(
                    x: clampX(mbX),
                    y: mbY + 14 * s + gap + cardHalfH
                )
            )
            
        default:
            return HighlightSpec(
                center: CGPoint(x: w / 2, y: h / 2),
                size: CGSize(width: 100, height: 100),
                isCircle: false,
                cardPosition: CGPoint(x: w / 2, y: h / 2 + 120)
            )
        }
    }
}

// MARK: - Guide Card Component

struct GuideCard: View {
    let index: Int
    let label: String
    let desc: String
    let note: String?
    let hasIcon: Bool
    
    @Binding var isVisible: Bool
    let s: CGFloat
    let engine: CognitiveLoadEngine
    
    var body: some View {
        HStack(alignment: .top, spacing: 12 * s) {
            if hasIcon {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 16 * s, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2 * s)
            }
            
            VStack(alignment: .leading, spacing: 6 * s) {
                Text(label)
                    .font(.system(size: 9 * s, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                
                Text(desc)
                    .font(.system(size: 11.5 * s, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let note = note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10 * s, weight: .medium, design: .rounded))
                        .foregroundColor(FlowColors.color(for: engine.animatedScore).opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 10 * s)
        .frame(width: 200 * s, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .opacity(isVisible ? 1.0 : 0.0)
    }
}
