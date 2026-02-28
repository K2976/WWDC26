import SwiftUI

// MARK: - Guide Overlay View

struct GuideOverlayView: View {
    let engine: CognitiveLoadEngine
    let demoManager: DemoManager
    let s: CGFloat
    let frames: [GuideID: CGRect]
    let dismiss: () -> Void
    
    @State private var currentStep = 0
    @State private var cardVisible = false
    @State private var spotlightVisible = false
    @State private var ringPulse = false
    
    // Step order maps to GuideIDs
    private let stepIDs: [GuideID] = [
        .orb, .score, .clock, .duration,
        .dnd, .sound, .reset, .analytics,
        .demo, .end
    ]
    
    private var totalSteps: Int { stepIDs.count }
    
    // Whether this step's highlight should be a circle
    private func isCircle(for id: GuideID) -> Bool {
        id == .orb || id == .analytics
    }
    
    // Guide content for each GuideID
    private func content(for id: GuideID) -> (label: String, desc: String, note: String?, hasIcon: Bool) {
        switch id {
        case .orb:
            return ("YOUR MIND, VISUALIZED",
                    "This 3D globe represents your cognitive load in real time. Color shifts from calm teal to stressed red as your attention fragments. Drag it to spin.",
                    nil, false)
        case .score:
            return ("COGNITIVE LOAD SCORE",
                    "0 is fully focused. 100 is overloaded. Score rises with distractions and decays naturally over time. The arrow shows current direction.",
                    nil, false)
        case .clock:
            return ("SESSION CLOCK",
                    demoManager.isDemoMode
                    ? "Running at 120× speed — shows a full day of attention patterns in minutes so you can see Flow's full range."
                    : "Current time. Tracks your focus session from when you set your attention level.",
                    demoManager.isDemoMode ? "120× demo speed" : nil, false)
        case .duration:
            return ("SESSION DURATION",
                    "Total time in your current focus session. Resets when you start a new one.",
                    nil, false)
        case .dnd:
            return ("DO NOT DISTURB",
                    "Toggles macOS Do Not Disturb so notifications don't break your flow. One tap silences everything — another brings them back.",
                    nil, false)
        case .sound:
            return ("BINAURAL BEATS",
                    "Flow generates real-time procedural audio — layered binaural beats that shift frequency with your cognitive load. Low scores play calming alpha waves; high scores introduce grounding theta pulses to ease you back.",
                    "Wear headphones for full effect", false)
        case .reset:
            return ("RESET",
                    "Guides your cognitive load score smoothly back to baseline. Use it after a break or context switch to start fresh without ending the session.",
                    nil, false)
        case .analytics:
            return ("ANALYTICS PANEL",
                    "Opens your attention timeline, 7-day history, and neuroscience insights about what's happening to your focus.",
                    nil, false)
        case .demo:
            return (demoManager.isDemoMode ? "DEMO MODE" : "DEMO TOGGLE",
                    demoManager.isDemoMode
                    ? "Currently auto-simulating distractions so you can see Flow react in real time. Tap to switch to live tracking mode."
                    : "Enables auto-simulation mode so you can explore Flow without real distractions.",
                    demoManager.isDemoMode ? "Auto-simulation active" : nil, false)
        case .end:
            return ("END SESSION",
                    "Closes your current focus session and shows your full attention summary — including timeline, peak score, and event breakdown.",
                    nil, false)
        case .menuBar:
            return ("MENU BAR COMPANION",
                    "A mini orb lives in your macOS menu bar at all times. Click it to check your score or log events without switching windows.",
                    nil, true)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let color = FlowColors.color(for: engine.animatedScore)
            let currentID = stepIDs[currentStep]
            let rect = frames[currentID] ?? CGRect(x: w/2 - 50, y: h/2 - 50, width: 100, height: 100)
            let pad: CGFloat = 12 * s
            let cutoutRect = rect.insetBy(dx: -pad, dy: -pad)
            let isOrbLike = isCircle(for: currentID)
            
            ZStack {
                // 1. Dark overlay with transparent cutout
                Color.black.opacity(0.85)
                    .overlay {
                        Group {
                            if isOrbLike {
                                let dim = max(cutoutRect.width, cutoutRect.height)
                                Circle()
                                    .frame(width: dim, height: dim)
                                    .position(
                                        x: cutoutRect.midX,
                                        y: cutoutRect.midY
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                                    .frame(width: cutoutRect.width, height: cutoutRect.height)
                                    .position(
                                        x: cutoutRect.midX,
                                        y: cutoutRect.midY
                                    )
                            }
                        }
                        .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .ignoresSafeArea()
                    .onTapGesture { advance() }
                
                // 2. Glowing highlight ring
                Group {
                    if isOrbLike {
                        let dim = max(cutoutRect.width, cutoutRect.height)
                        Circle()
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                            .frame(width: dim, height: dim)
                            .position(x: cutoutRect.midX, y: cutoutRect.midY)
                    } else {
                        RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                            .stroke(color.opacity(0.6), lineWidth: 1.5)
                            .frame(width: cutoutRect.width, height: cutoutRect.height)
                            .position(x: cutoutRect.midX, y: cutoutRect.midY)
                    }
                }
                .shadow(color: color.opacity(0.4), radius: 10)
                .shadow(color: color.opacity(0.2), radius: 24)
                .scaleEffect(ringPulse ? 1.03 : 1.0)
                .opacity(ringPulse ? 0.7 : 1.0)
                .opacity(spotlightVisible ? 1 : 0)
                .allowsHitTesting(false)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: ringPulse
                )
                
                // 3. Guide card positioned near the feature
                if currentStep < totalSteps {
                    let info = content(for: currentID)
                    let cardW: CGFloat = 200 * s
                    let cardPos = cardPosition(
                        for: cutoutRect,
                        isOrb: isOrbLike,
                        cardWidth: cardW,
                        viewW: w, viewH: h
                    )
                    
                    GuideCard(
                        label: info.label,
                        desc: info.desc,
                        note: info.note,
                        hasIcon: info.hasIcon,
                        isVisible: $cardVisible,
                        s: s,
                        engine: engine
                    )
                    .position(x: cardPos.x, y: cardPos.y)
                    .transition(.opacity)
                }
                
                // 4. Close button — top right
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12 * s, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 28 * s, height: 28 * s)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.08))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16 * s)
                        .padding(.trailing, 16 * s)
                    }
                    Spacer()
                }
                
                // 5. Navigation row
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
    
    // MARK: - Card Positioning
    
    /// Places the card above or below the highlighted element, clamped on-screen
    private func cardPosition(for rect: CGRect, isOrb: Bool, cardWidth: CGFloat, viewW: CGFloat, viewH: CGFloat) -> CGPoint {
        let cardH: CGFloat = 130 * s  // estimated card height
        let gap: CGFloat = 14 * s
        
        // Is the element in the top or bottom half?
        let isTop = rect.midY < viewH / 2
        
        let y: CGFloat
        if isTop {
            // Card goes below the element
            y = rect.maxY + gap + cardH / 2
        } else {
            // Card goes above the element
            y = rect.minY - gap - cardH / 2
        }
        
        // Clamp Y so the card stays on screen
        let clampedY = max(cardH / 2 + 10, min(viewH - cardH / 2 - 80 * s, y))
        
        // X: center on element, clamped to stay on screen
        let halfW = cardWidth / 2
        let clampedX = max(halfW + 16 * s, min(viewW - halfW - 16 * s, rect.midX))
        
        return CGPoint(x: clampedX, y: clampedY)
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
}

// MARK: - Guide Card Component

struct GuideCard: View {
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
