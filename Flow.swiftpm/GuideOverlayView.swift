import SwiftUI

// MARK: - Guide Overlay View

struct GuideOverlayView: View {
    let engine: CognitiveLoadEngine
    let demoManager: DemoManager
    let s: CGFloat
    let dismiss: () -> Void
    
    @State private var stage: [Bool] = Array(repeating: false, count: 9)
    @State private var labelsStage: [Bool] = Array(repeating: false, count: 9)
    @State private var labelOffsets: [CGFloat] = Array(repeating: 8, count: 9)
    
    var body: some View {
        ZStack {
            // 1. Background Dim & Cutouts
            ZStack {
                Color.black.opacity(0.75)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .onTapGesture {
                        dismiss()
                    }
                
                spotlightsLayout(isCutout: true)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            
            // 2. Glows (Halos)
            spotlightsLayout(isCutout: false)
                .allowsHitTesting(false)
            
            // 3. Labels
            labelsLayout()
                .allowsHitTesting(false)
            
            // 4. "Got it" button
            VStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Capsule()
                        .fill(FlowColors.color(for: engine.animatedScore).opacity(0.25))
                        .overlay(Capsule().stroke(
                            FlowColors.color(for: engine.animatedScore).opacity(0.5),
                            lineWidth: 0.5))
                        .frame(width: 140 * s, height: 44 * s)
                        .overlay(
                            Text("Got it  →")
                                .font(.system(size: 15 * s, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40 * s)
                .opacity(stage[1] ? 1.0 : 0.0) // Fades in with the rest
            }
        }
        .onAppear {
            for i in 1...8 {
                let delay = Double(i - 1) * 0.07
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        stage[i] = true
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                        labelsStage[i] = true
                        labelOffsets[i] = 0.0
                    }
                }
            }
        }
    }
    
    // MARK: - Spotlights Layout
    
    @ViewBuilder
    private func spotlightsLayout(isCutout: Bool) -> some View {
        ZStack {
            // 1: Center Orb
            GeometryReader { geo in
                let orbSize = min(max(min(geo.size.width, geo.size.height) * 0.52, 180), 700)
                VStack(spacing: 20 * s) {
                    spotlightShape(index: 1, isRound: true, width: orbSize + 24 * s, height: orbSize + 24 * s, isCutout: isCutout)
                    Color.clear.frame(height: 50 * s) // Matched to the text underneath orb
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Edge Controls
            VStack(spacing: 0) {
                // Top Row
                HStack(alignment: .center) {
                    HStack {
                        spotlightShape(index: 3, isRound: false, width: 200 * s, height: 80 * s, isCutout: isCutout)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        spotlightShape(index: 2, isRound: false, width: 140 * s, height: 90 * s, isCutout: isCutout)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        spotlightShape(index: 4, isRound: false, width: 130 * s, height: 75 * s, isCutout: isCutout)
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28 * s)
                .padding(.top, 20 * s)
                
                Spacer()
                
                // Bottom Row
                HStack(alignment: .center) {
                    HStack {
                        // Spans DND, sound, reset, ?
                        spotlightShape(index: 5, isRound: false, width: 280 * s, height: 50 * s, isCutout: isCutout)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        spotlightShape(index: 6, isRound: true, width: 44 * s, height: 44 * s, isCutout: isCutout)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        spotlightShape(index: 7, isRound: false, width: 160 * s, height: 50 * s, isCutout: isCutout)
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28 * s)
                .padding(.bottom, 20 * s)
            }
        }
    }
    
    @ViewBuilder
    private func spotlightShape(index: Int, isRound: Bool, width: CGFloat, height: CGFloat, isCutout: Bool) -> some View {
        let radius = isRound ? width / 2 : 20 * s
        
        ZStack {
            if isCutout {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.black)
                    .frame(width: width, height: height)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(FlowColors.color(for: engine.animatedScore).opacity(0.15))
                    .frame(width: width + 12 * s, height: height + 12 * s)
                    .blur(radius: 16)
            }
        }
        .scaleEffect(stage[index] ? 1.0 : 0.92)
        .opacity(stage[index] ? 1.0 : 0.0)
    }
    
    // MARK: - Labels Layout
    
    @ViewBuilder
    private func labelsLayout() -> some View {
        ZStack {
            // Floating 8 (Menu bar)
            VStack {
                HStack {
                    Spacer()
                    GuideCard(
                        index: 8,
                        label: "MENU BAR COMPANION",
                        desc: "A mini orb lives in your macOS menu bar at all times. Click it to check your score or log events without switching windows.",
                        note: nil,
                        hasIcon: true,
                        stage: $labelsStage,
                        offsets: $labelOffsets,
                        s: s,
                        engine: engine
                    )
                }
                Spacer()
            }
            .padding(24 * s)
            
            // 1: Center Orb
            GeometryReader { geo in
                let orbSize = min(max(min(geo.size.width, geo.size.height) * 0.52, 180), 700)
                VStack {
                    Color.clear.frame(height: orbSize + 48 * s) // Push down
                    GuideCard(
                        index: 1,
                        label: "YOUR MIND, VISUALIZED",
                        desc: "This 3D globe represents your cognitive load in real time. Color shifts from calm teal to stressed red as your attention fragments. Drag it to spin.",
                        note: nil,
                        hasIcon: false,
                        stage: $labelsStage,
                        offsets: $labelOffsets,
                        s: s,
                        engine: engine
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Edge Controls
            VStack(spacing: 0) {
                // Top Row
                HStack(alignment: .top) {
                    HStack {
                        GuideCard(
                            index: 3,
                            label: "SESSION CLOCK",
                            desc: demoManager.isDemoMode ? "Running at 120× speed — shows a full day of attention patterns in minutes so you can see Flow's full range." : "Current time. Tracks your focus session from when you set your attention level.",
                            note: demoManager.isDemoMode ? "120× demo speed" : nil,
                            hasIcon: false,
                            stage: $labelsStage,
                            offsets: $labelOffsets,
                            s: s,
                            engine: engine
                        )
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        GuideCard(
                            index: 2,
                            label: "COGNITIVE LOAD SCORE",
                            desc: "0 is fully focused. 100 is overloaded. Score rises with distractions and decays naturally over time. The arrow shows current direction.",
                            note: nil,
                            hasIcon: false,
                            stage: $labelsStage,
                            offsets: $labelOffsets,
                            s: s,
                            engine: engine
                        )
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        VStack {
                            GuideCard(
                                index: 4,
                                label: "SESSION DURATION",
                                desc: "Total time in your current focus session. Resets when you start a new one.",
                                note: nil,
                                hasIcon: false,
                                stage: $labelsStage,
                                offsets: $labelOffsets,
                                s: s,
                                engine: engine
                            )
                        }
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28 * s)
                .padding(.top, 120 * s) // Offset below top spotlighs
                
                Spacer()
                
                // Bottom Row
                HStack(alignment: .bottom) {
                    HStack {
                        GuideCard(
                            index: 5,
                            label: "SESSION CONTROLS",
                            desc: "DND toggles Do Not Disturb. Sound toggles procedurally synthesized ambient beats that shift with your score. Reset guides your score back to baseline with an animated recovery.",
                            note: nil,
                            hasIcon: false,
                            stage: $labelsStage,
                            offsets: $labelOffsets,
                            s: s,
                            engine: engine
                        )
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        GuideCard(
                            index: 6,
                            label: "ANALYTICS PANEL",
                            desc: "Opens your attention timeline, 7-day history, and neuroscience insights about what's happening to your focus.",
                            note: nil,
                            hasIcon: false,
                            stage: $labelsStage,
                            offsets: $labelOffsets,
                            s: s,
                            engine: engine
                        )
                        Spacer()
                    }.frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        GuideCard(
                            index: 7,
                            label: demoManager.isDemoMode ? "DEMO CONTROLS" : "SESSION CONTROLS",
                            desc: demoManager.isDemoMode ? "DEMO is auto-simulating distractions so you can see Flow react in real time. END closes this session and shows your full attention summary." : "Flow is tracking real app switches and idle time via macOS system events. END closes the session and shows your stats.",
                            note: demoManager.isDemoMode ? "Auto-simulation active" : "Live system tracking active",
                            hasIcon: false,
                            stage: $labelsStage,
                            offsets: $labelOffsets,
                            s: s,
                            engine: engine
                        )
                    }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28 * s)
                .padding(.bottom, 80 * s) // Offset above bottom controls
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
    
    @Binding var stage: [Bool]
    @Binding var offsets: [CGFloat]
    let s: CGFloat
    let engine: CognitiveLoadEngine
    
    var body: some View {
        HStack(alignment: .top, spacing: 12 * s) {
            if hasIcon {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 18 * s, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2 * s)
            }
            
            VStack(alignment: .leading, spacing: 6 * s) {
                Text(label)
                    .font(.system(size: 10 * s, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                
                Text(desc)
                    .font(.system(size: 13 * s, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let note = note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11 * s, weight: .medium, design: .rounded))
                        .foregroundColor(FlowColors.color(for: engine.animatedScore).opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 14 * s)
        .padding(.vertical, 12 * s)
        .frame(width: 220 * s, alignment: .leading)
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
        .opacity(stage[index] ? 1.0 : 0.0)
        .offset(y: offsets[index])
    }
}
