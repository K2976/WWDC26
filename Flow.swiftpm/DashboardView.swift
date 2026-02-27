import SwiftUI

// MARK: - Main Dashboard View

struct DashboardView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Environment(DemoManager.self) private var demoManager
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SimulationManager.self) private var simulation
    @Environment(RealEventDetector.self) private var realDetector
    @Environment(AudioManager.self) private var audio
    
    let haptics: HapticsManager
    
    @State private var showRecovery = false
    @State private var currentTip = ScienceInsights.randomInsight()
    @State private var currentTime = Date()
    @State private var showDetails = false
    
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Main Dashboard Content
            ZStack {
                AmbientBackground()
                    .ignoresSafeArea()
                
                // Center: Orb + state labels
                GeometryReader { geo in
                    let orbSize = min(max(min(geo.size.width, geo.size.height) * 0.52, 180), 700)
                    VStack(spacing: 20) {
                        FocusOrbView(score: engine.animatedScore, size: orbSize)
                        
                        VStack(spacing: 8) {
                            // State label
                            Text(engine.state.label)
                                .font(FlowTypography.labelFont(size: 22))
                                .foregroundStyle(.white.opacity(0.4))
                                .animation(.easeInOut(duration: 1.5), value: engine.state)
                            
                            // Contextual line
                            Text(engine.state.contextualLine)
                                .font(FlowTypography.bodyFont(size: 15))
                                .foregroundStyle(.white.opacity(0.25))
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 1.5), value: engine.state)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Edge-anchored controls overlay
                VStack(spacing: 0) {
                    // ── Top row ──
                    topControls
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // ── Bottom row ──
                    bottomControls
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                }
                
                // Slide-up detail panel with dismissible backdrop
                if showDetails {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showDetails = false
                            }
                        }
                        .transition(.opacity)
                    
                    detailPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Recovery overlay
            if showRecovery {
                RecoveryView(isPresented: $showRecovery)
            }
            
            // Session summary overlay
            if sessionManager.showingSummary, let session = sessionManager.lastSession {
                SessionSummaryView(session: session)
            }
        }
        .onReceive(clockTimer) { _ in
            currentTime = demoManager.currentDate
        }
        .onChange(of: engine.score) { _, newScore in
            if newScore > 85 && !showRecovery && !engine.isFocusMode {
                showRecovery = true
            }
            audio.updateForScore(newScore)
        }
        .onAppear {
            audio.startAmbient()
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        ZStack {
            // Center: Cognitive load number
            Text("\(Int(engine.animatedScore))")
                .font(FlowTypography.headingFont(size: 64))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: Int(engine.animatedScore))
            
            // Leading: Flip clock
            HStack {
                CompactFlipClockView(date: currentTime)
                Spacer()
            }
            
            // Trailing: Session stopwatch in soft box
            HStack {
                Spacer()
                Text(sessionManager.formattedDuration)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.04), lineWidth: 0.5)
                    )
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        ZStack {
            // Center: Details toggle chevron
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showDetails.toggle()
                }
            } label: {
                Image(systemName: showDetails ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.04), lineWidth: 0.5)
                    )
                    .animation(.easeOut(duration: 0.25), value: showDetails)
            }
            .buttonStyle(.plain)
            .focusable(false)
            
            // Leading: DND + Sound toggle
            HStack {
                HStack(spacing: 10) {
                    // Focus Mode (DND) Toggle
                    Button {
                        withAnimation(FlowAnimation.viewTransition) {
                            engine.isFocusMode.toggle()
                            audio.setFocusMode(engine.isFocusMode)
                            toggleMacOSFocus(engine.isFocusMode)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 12))
                            Text("DND")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .tracking(0.6)
                        }
                        .foregroundStyle(engine.isFocusMode ? .white.opacity(0.85) : .white.opacity(0.35))
                        .frame(height: 20)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.04), lineWidth: 0.5)
                        )
                        .animation(.easeOut(duration: 0.25), value: engine.isFocusMode)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .keyboardShortcut("f", modifiers: .command)
                    
                    // Sliding sound toggle
                    soundToggle
                        .frame(height: 20)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.04), lineWidth: 0.5)
                        )
                }
                Spacer()
            }
            
            // Trailing: DEMO + END
            HStack {
                Spacer()
                HStack(spacing: 10) {
                    // Demo Mode Toggle
                    Button {
                        withAnimation(FlowAnimation.viewTransition) {
                            demoManager.isDemoMode.toggle()
                            sessionManager.setDemoMode(demoManager.isDemoMode)
                            
                            if demoManager.isDemoMode {
                                realDetector.stop()
                                simulation.userHasInteracted = false
                                simulation.startSimulation(engine: engine)
                            } else {
                                simulation.stopSimulation()
                                realDetector.start(engine: engine)
                            }
                        }
                    } label: {
                        Text("DEMO")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(demoManager.isDemoMode ? .white.opacity(0.7) : .white.opacity(0.35))
                            .frame(height: 20)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.04), lineWidth: 0.5)
                            )
                            .animation(.easeOut(duration: 0.25), value: demoManager.isDemoMode)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    
                    // End Session
                    Button {
                        sessionManager.endSession(engine: engine)
                        audio.playCompletionChime()
                        haptics.playCompletionHaptic()
                    } label: {
                        Text("END")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(height: 20)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.04), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
        }
    }
    
    // MARK: - Sound Toggle
    
    private var soundToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                audio.isMuted.toggle()
                if audio.isMuted {
                    audio.stopAmbient()
                } else {
                    audio.startAmbient()
                }
            }
        } label: {
            ZStack {
                // Sliding highlight behind active icon
                HStack {
                    if !audio.isMuted { Spacer() }
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .frame(width: 28, height: 20)
                    if audio.isMuted { Spacer() }
                }
                
                // Two icons side by side
                HStack(spacing: 10) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(audio.isMuted ? 0.7 : 0.25))
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(audio.isMuted ? 0.25 : 0.7))
                }
            }
            .frame(width: 56)
            .animation(.easeOut(duration: 0.25), value: audio.isMuted)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
    
    // MARK: - Detail Panel (Slides Up on Interaction)
    
    private var detailPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Drag handle
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Score
                HStack(spacing: 8) {
                    Text("\(Int(engine.animatedScore))")
                        .font(FlowTypography.scoreFont(size: 32))
                        .foregroundStyle(.white.opacity(0.5))
                        .contentTransition(.numericText())
                        .animation(FlowAnimation.scoreChange, value: Int(engine.animatedScore))
                    
                    Text("cognitive load")
                        .font(FlowTypography.captionFont(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                }
                
                // Event buttons (demo mode only)
                if demoManager.isDemoMode {
                    eventButtonsSection
                        .padding(.horizontal, 24)
                }
                
                // Graph
                CognitiveLoadGraphView()
                    .padding(.horizontal, 24)
                
                // History strip
                HistoryStripView()
                    .padding(.horizontal, 24)
                
                // Science tip
                Button {
                    currentTip = ScienceInsights.randomInsight()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                        Text(currentTip)
                            .font(FlowTypography.captionFont(size: 10))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
            .focusable(false)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hue: 0.62, saturation: 0.35, brightness: 0.12).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Event Buttons
    
    private var eventButtonsSection: some View {
        VStack(spacing: 6) {
            Text("LOG ATTENTION EVENT")
                .font(FlowTypography.captionFont(size: 9))
                .foregroundStyle(.white.opacity(0.15))
                .tracking(1.5)
            
            HStack(spacing: 10) {
                ForEach(AttentionEvent.allCases.filter(\.isManual)) { event in
                    eventButton(event)
                }
            }
        }
    }
    
    private func eventButton(_ event: AttentionEvent) -> some View {
        Button {
            logEvent(event)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: event.symbol)
                    .font(.system(size: 14))
                
                Text(event.rawValue)
                    .font(FlowTypography.captionFont(size: 10))
                
                Text("+\(Int(event.loadIncrease))")
                    .font(FlowTypography.captionFont(size: 9))
                    .foregroundStyle(.white.opacity(0.15))
            }
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.03), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func logEvent(_ event: AttentionEvent) {
        simulation.userHasInteracted = true
        engine.logEvent(event)
        haptics.playEventFeedback()
        audio.playEventChime()
    }
    
    // MARK: - macOS Focus Mode
    
    private func toggleMacOSFocus(_ enabled: Bool) {
        #if os(macOS)
        Task.detached {
            let script: String
            if enabled {
                script = """
                tell application "System Events"
                    tell process "ControlCenter"
                        click menu bar item "Focus" of menu bar 1
                        delay 0.5
                        try
                            click checkbox "Do Not Disturb" of group 1 of section 1 of window "Control Center"
                        end try
                    end tell
                end tell
                """
            } else {
                script = """
                tell application "System Events"
                    tell process "ControlCenter"
                        click menu bar item "Focus" of menu bar 1
                        delay 0.5
                        try
                            click checkbox "Do Not Disturb" of group 1 of section 1 of window "Control Center"
                        end try
                        delay 0.3
                        key code 53
                    end tell
                end tell
                """
            }
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
        #endif
    }
}
