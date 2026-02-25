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
    @State private var isTypingMode = false
    
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Main Dashboard Content
            ZStack {
                AmbientBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
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
                    
                    Spacer()
                    
                    bottomControls
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
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
            // Hide main dashboard when typing mode is active
            .opacity(isTypingMode ? 0 : 1)
            .animation(.easeInOut(duration: 0.8), value: isTypingMode)
            
            // Recovery overlay
            if showRecovery {
                RecoveryView(isPresented: $showRecovery)
            }
            
            // Session summary overlay
            if sessionManager.showingSummary, let session = sessionManager.lastSession {
                SessionSummaryView(session: session)
            }
            
            // Typing Test Mode
            if isTypingMode {
                TypingModeView {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isTypingMode = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onReceive(clockTimer) { _ in
            currentTime = Date()
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
    
    // MARK: - Header (Minimal, Transparent)
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flow")
                    .font(FlowTypography.headingFont(size: 26))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text(currentTime, style: .time)
                    .font(FlowTypography.captionFont(size: 15))
                    .foregroundStyle(.white.opacity(0.25))
            }
            
            Spacer()
            
            // Score Meter (Big, Top Center-Right)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(engine.animatedScore))")
                    .font(FlowTypography.headingFont(size: 64))
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: Int(engine.animatedScore))
                
                Text("cognitive load")
                    .font(FlowTypography.labelFont(size: 18))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.trailing, 24)
            
            Spacer()
            
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
                    .foregroundStyle(demoManager.isDemoMode ? .white.opacity(0.6) : .white.opacity(0.25))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(demoManager.isDemoMode ?
                                  .white.opacity(0.08) :
                                  .white.opacity(0.03))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            // Mute Toggle
            Button {
                audio.isMuted.toggle()
                if audio.isMuted {
                    audio.stopAmbient()
                } else {
                    audio.startAmbient()
                }
            } label: {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(audio.isMuted ? .white.opacity(0.15) : .white.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            // Typing Test Mode Button
            Button {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isTypingMode = true
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            // Focus Mode Toggle
            Button {
                withAnimation(FlowAnimation.viewTransition) {
                    engine.isFocusMode.toggle()
                    audio.setFocusMode(engine.isFocusMode)
                    toggleMacOSFocus(engine.isFocusMode)
                }
            } label: {
                Image(systemName: engine.isFocusMode ? "moon.fill" : "moon")
                    .font(.system(size: 16))
                    .foregroundStyle(engine.isFocusMode ? .white.opacity(0.6) : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(engine.isFocusMode ?
                                  .white.opacity(0.08) :
                                  .white.opacity(0.03))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(engine.isFocusMode ? 0.1 : 0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
        }
    }
    
    // MARK: - Orb Section (Centered, Dominant)
    
    // This section is now integrated directly into the body's main VStack.
    // The `orbSection` private var is no longer needed.
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack {
            // Session timer
            Text(sessionManager.formattedDuration)
                .font(FlowTypography.captionFont(size: 11))
                .foregroundStyle(.white.opacity(0.2))
                .monospacedDigit()
            
            Spacer()
            
            // Details toggle
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showDetails.toggle()
                }
            } label: {
                Image(systemName: showDetails ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // End Session
            Button {
                sessionManager.endSession(engine: engine)
                audio.playCompletionChime()
                haptics.playCompletionHaptic()
            } label: {
                Text("End")
                    .font(FlowTypography.captionFont(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(.white.opacity(0.03))
                    )
                    .overlay(
                        Capsule().stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
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
                    .fill(.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.05), lineWidth: 0.5)
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
