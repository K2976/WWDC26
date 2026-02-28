import SwiftUI

// MARK: - Guide Overlay View

struct GuideOverlayView: View {
    let engine: CognitiveLoadEngine
    let demoManager: DemoManager
    let s: CGFloat
    let dismiss: () -> Void
    
    @State private var currentStep = 0
    @State private var cardVisible = false
    @State private var spotlightVisible = false
    
    // Total guide steps (indices 1–10)
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
        ZStack {
            // Background dim
            Color.black.opacity(0.85)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .onTapGesture { advance() }
            
            // Spotlight for current step
            if currentStep < totalSteps {
                spotlightsLayout(for: steps[currentStep].index)
                    .allowsHitTesting(false)
                    .opacity(spotlightVisible ? 1 : 0)
            }
            
            // Current card — centered
            VStack {
                Spacer()
                
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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                
                // Navigation row
                HStack(spacing: 16 * s) {
                    // Step indicator dots
                    HStack(spacing: 6 * s) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep
                                      ? FlowColors.color(for: engine.animatedScore)
                                      : .white.opacity(i < currentStep ? 0.3 : 0.12))
                                .frame(width: 6 * s, height: 6 * s)
                        }
                    }
                    
                    Spacer()
                    
                    // Next / Done button
                    Button { advance() } label: {
                        Capsule()
                            .fill(FlowColors.color(for: engine.animatedScore).opacity(0.25))
                            .overlay(Capsule().stroke(
                                FlowColors.color(for: engine.animatedScore).opacity(0.5),
                                lineWidth: 0.5))
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
        .onAppear { showStep() }
    }
    
    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeOut(duration: 0.2)) {
                cardVisible = false
                spotlightVisible = false
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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            cardVisible = true
            spotlightVisible = true
        }
    }
    
    // MARK: - Spotlight for a single step
    
    @ViewBuilder
    private func spotlightsLayout(for index: Int) -> some View {
        let color = FlowColors.color(for: engine.animatedScore)
        
        ZStack {
            switch index {
            case 1: // Center Orb
                GeometryReader { geo in
                    let orbSize = min(max(min(geo.size.width, geo.size.height) * 0.52, 180), 700)
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: orbSize + 36 * s, height: orbSize + 36 * s)
                        .blur(radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case 2: // Score — top center
                VStack {
                    RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 160 * s, height: 100 * s)
                        .blur(radius: 16)
                        .padding(.top, 16 * s)
                    Spacer()
                }
            case 3: // Clock — top left
                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 200 * s, height: 90 * s)
                            .blur(radius: 16)
                        Spacer()
                    }
                    .padding(.leading, 24 * s)
                    .padding(.top, 16 * s)
                    Spacer()
                }
            case 4: // Duration — top right
                VStack {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 140 * s, height: 80 * s)
                            .blur(radius: 16)
                    }
                    .padding(.trailing, 24 * s)
                    .padding(.top, 16 * s)
                    Spacer()
                }
            case 5: // DND — bottom left (first button)
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 80 * s, height: 60 * s)
                            .blur(radius: 16)
                        Spacer()
                    }
                    .padding(.leading, 24 * s)
                    .padding(.bottom, 16 * s)
                }
            case 6: // Binaural Beats — bottom left (second button)
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 80 * s, height: 60 * s)
                            .blur(radius: 16)
                        Spacer()
                    }
                    .padding(.leading, 110 * s)
                    .padding(.bottom, 16 * s)
                }
            case 7: // Reset — bottom left (third button)
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 90 * s, height: 60 * s)
                            .blur(radius: 16)
                        Spacer()
                    }
                    .padding(.leading, 196 * s)
                    .padding(.bottom, 16 * s)
                }
            case 8: // Analytics — bottom center
                VStack {
                    Spacer()
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56 * s, height: 56 * s)
                        .blur(radius: 16)
                        .padding(.bottom, 16 * s)
                }
            case 9: // Demo/End — bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 170 * s, height: 60 * s)
                            .blur(radius: 16)
                    }
                    .padding(.trailing, 24 * s)
                    .padding(.bottom, 16 * s)
                }
            case 10: // Menu bar — very top right
                VStack {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                            .fill(color.opacity(0.15))
                            .frame(width: 40 * s, height: 28 * s)
                            .blur(radius: 12)
                    }
                    .padding(.trailing, 60 * s)
                    .padding(.top, 4 * s)
                    Spacer()
                }
            default:
                EmptyView()
            }
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
        .frame(width: 190 * s, alignment: .leading)
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
