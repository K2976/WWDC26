import SwiftUI

// MARK: - Main Dashboard View

struct DashboardView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SimulationManager.self) private var simulation
    @Environment(AudioManager.self) private var audio
    
    let haptics: HapticsManager
    
    @State private var showRecovery = false
    @State private var currentTip = ScienceInsights.randomInsight()
    @State private var orbPulseAmount: CGFloat = 1.0
    @State private var currentTime = Date()
    
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Dynamic background
            FlowColors.backgroundColor(for: engine.animatedScore)
                .ignoresSafeArea()
                .animation(FlowAnimation.colorTransition, value: engine.animatedScore)
            
            VStack(spacing: 0) {
                // Fixed top bar
                headerSection
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        FlowColors.backgroundColor(for: engine.animatedScore)
                            .opacity(0.95)
                            .overlay(
                                Rectangle()
                                    .fill(.white.opacity(0.04))
                            )
                    )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(.white.opacity(0.06))
                            .frame(height: 0.5)
                    }
                
                // Scrollable content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Center orb area
                        orbSection
                            .padding(.top, 24)
                        
                        // Event buttons
                        eventButtonsSection
                            .padding(.horizontal, 32)
                            .padding(.top, 24)
                        
                        // Graph
                        CognitiveLoadGraphView()
                            .padding(.horizontal, 32)
                            .padding(.top, 20)
                        
                        // History strip
                        HistoryStripView()
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                        
                        // Bottom bar
                        bottomBar
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                    }
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
            currentTime = Date()
        }
        .onChange(of: engine.score) { _, newScore in
            // Show recovery when overloaded
            if newScore > 85 && !showRecovery && !engine.isFocusMode {
                showRecovery = true
            }
            // Update audio
            audio.updateForScore(newScore)
        }
        .onAppear {
            audio.startAmbient()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flow")
                    .font(FlowTypography.headingFont(size: 22))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text(currentTime, style: .time)
                    .font(FlowTypography.captionFont(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
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
                    .font(.system(size: 14))
                    .foregroundStyle(audio.isMuted ? .white.opacity(0.3) : .white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.white.opacity(audio.isMuted ? 0.04 : 0.06))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.08), lineWidth: 0.5)
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
                    .font(.system(size: 14))
                    .foregroundStyle(engine.isFocusMode ? .white : .white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(engine.isFocusMode ?
                                  FlowColors.color(for: 30).opacity(0.3) :
                                  .white.opacity(0.06))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(engine.isFocusMode ? 0.2 : 0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
        }
    }
    
    // MARK: - Orb Section
    
    private var orbSection: some View {
        VStack(spacing: 16) {
            // Orb
            FocusOrbView(score: engine.animatedScore, size: 220)
                .scaleEffect(orbPulseAmount)
            
            // Score
            Text("\(Int(engine.animatedScore))")
                .font(FlowTypography.scoreFont(size: 56))
                .foregroundStyle(.white.opacity(0.95))
                .contentTransition(.numericText())
                .animation(FlowAnimation.scoreChange, value: Int(engine.animatedScore))
            
            // State label
            Text(engine.state.label)
                .font(FlowTypography.labelFont(size: 18))
                .foregroundStyle(FlowColors.color(for: engine.animatedScore))
                .animation(FlowAnimation.colorTransition, value: engine.state)
            
            // Contextual line
            Text(engine.state.contextualLine)
                .font(FlowTypography.bodyFont(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .transition(.opacity)
                .animation(.easeInOut(duration: 1.0), value: engine.state)
        }
    }
    
    // MARK: - Event Buttons
    
    private var eventButtonsSection: some View {
        VStack(spacing: 8) {
            Text("LOG ATTENTION EVENT")
                .font(FlowTypography.captionFont(size: 10))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
            
            HStack(spacing: 12) {
                ForEach(AttentionEvent.allCases) { event in
                    eventButton(event)
                }
            }
        }
    }
    
    private func eventButton(_ event: AttentionEvent) -> some View {
        Button {
            logEvent(event)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: event.symbol)
                    .font(.system(size: 16))
                
                Text(event.rawValue)
                    .font(FlowTypography.captionFont(size: 11))
                
                Text("+\(Int(event.loadIncrease))")
                    .font(FlowTypography.captionFont(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func logEvent(_ event: AttentionEvent) {
        simulation.userHasInteracted = true
        engine.logEvent(event)
        haptics.playEventFeedback()
        audio.playEventChime()
        
        // Orb pulse animation
        withAnimation(.easeOut(duration: 0.15)) {
            orbPulseAmount = 1.08
        }
        withAnimation(.easeInOut(duration: 0.4).delay(0.15)) {
            orbPulseAmount = 1.0
        }
    }
    
    // MARK: - macOS Focus Mode
    
    private func toggleMacOSFocus(_ enabled: Bool) {
        #if os(macOS)
        // Use shortcuts CLI to run a Focus shortcut if available,
        // otherwise fall back to AppleScript to toggle Do Not Disturb
        Task.detached {
            let script: String
            if enabled {
                script = """
                tell application "System Events"
                    tell process "ControlCenter"
                        -- Click Focus in menu bar
                        click menu bar item "Focus" of menu bar 1
                        delay 0.5
                        -- Click Do Not Disturb
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
                        -- Dismiss the panel
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
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            // Science tip
            Button {
                currentTip = ScienceInsights.randomInsight()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text(currentTip)
                        .font(FlowTypography.captionFont(size: 11))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: 300, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Session timer
            Text(sessionManager.formattedDuration)
                .font(FlowTypography.bodyFont(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .monospacedDigit()
            
            // End Session
            Button {
                sessionManager.endSession(engine: engine)
                audio.playCompletionChime()
                haptics.playCompletionHaptic()
            } label: {
                Text("End Session")
                    .font(FlowTypography.captionFont(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(.white.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
