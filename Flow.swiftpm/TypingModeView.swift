import SwiftUI

struct TypingModeView: View {
    @State private var engine = TypingEngine()
    @FocusState private var isFocused: Bool
    
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Dark minimal background
            Color(hue: 0.62, saturation: 0.2, brightness: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header (Settings / Close)
                header
                
                Spacer()
                
                // Main Content
                if engine.state == .finished {
                    resultsView
                } else {
                    typingArea
                }
                
                Spacer()
                
                // Footer (Hint)
                if engine.state == .idle {
                    Text("start typing to begin")
                        .font(FlowTypography.captionFont(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                } else if engine.state == .typing {
                    // Hidden or very subtle timer if time mode, 
                    // user requested NO live ticking timers, so we omit it completely to stay calm.
                    Text("focus")
                        .font(FlowTypography.captionFont(size: 14))
                        .foregroundStyle(.white.opacity(0.1))
                } else if engine.state == .finished {
                     Button(action: {
                         engine.setupTest()
                     }) {
                         Image(systemName: "arrow.clockwise")
                             .font(.system(size: 20))
                             .foregroundStyle(.white.opacity(0.5))
                             .padding(16)
                             .background(Circle().fill(.white.opacity(0.05)))
                     }
                     .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .onAppear {
            isFocused = true
        }
        // Force focus back if lost while testing
        .onChange(of: engine.state) { old, new in
            if new == .idle || new == .typing {
                isFocused = true
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            // Settings options (only interactable when idle)
            HStack(spacing: 20) {
                if engine.state == .idle {
                    modeButton(title: "15s", mode: .time(seconds: 15))
                    modeButton(title: "30s", mode: .time(seconds: 30))
                    modeButton(title: "60s", mode: .time(seconds: 60))
                    
                    Divider().frame(height: 12).background(.white.opacity(0.2))
                    
                    modeButton(title: "25w", mode: .words(count: 25))
                    modeButton(title: "50w", mode: .words(count: 50))
                }
            }
            // Fade out during test for maximum immersion
            .opacity(engine.state == .typing ? 0 : 1)
            .animation(.easeInOut, value: engine.state)
            
            Spacer()
            
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(12)
                    .background(Circle().fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func modeButton(title: String, mode: TypingTestMode) -> some View {
        let isSelected = engine.mode == mode
        return Button(action: {
            withAnimation { engine.setMode(mode) }
        }) {
            Text(title)
                .font(FlowTypography.captionFont(size: 14))
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.3))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Typing Area
    private var typingArea: some View {
        ZStack {
            // Invisible text field to capture input robustly
            TextField("", text: $engine.currentInput)
                .focused($isFocused)
                // Disable autocorrect and autocapitalization to prevent assistance
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .opacity(0)
                .frame(width: 0, height: 0)
            
            // Render the words using a flowed text approach
            // We only render window of words around current index to handle long modes
            let windowRadius = 15
            let startIndex = max(0, engine.currentWordIndex - windowRadius)
            let endIndex = min(engine.words.count, engine.currentWordIndex + windowRadius * 2)
            
            if endIndex > startIndex {
                let windowWords = engine.words[startIndex..<endIndex]
                
                // Combine into a single text block so it wraps naturally
                windowWords.enumerated().reduce(Text("")) { (result, args) in
                    let (offset, word) = args
                    let globalIndex = startIndex + offset
                    let isCurrent = globalIndex == engine.currentWordIndex
                    let isPast = globalIndex < engine.currentWordIndex
                    
                    let renderedWord: Text
                    
                    if isPast {
                        // Completed words fade subtly
                        renderedWord = Text(word.text)
                            .foregroundColor(word.isCorrectlyTyped ? .white.opacity(0.2) : Color.red.opacity(0.4))
                    } else if isCurrent {
                        // Current word being typed (split into typed prefix and upcoming postfix)
                        let typedPrefix = word.typed
                        let isTypingError = word.hasErrors
                        
                        // We highlight errors with a slight opacity shift rather than sharp red, keeping it calm
                        let highlightColor = isTypingError ? Color.orange.opacity(0.8) : .white.opacity(0.9)
                        
                        // Render mixed
                        if typedPrefix.isEmpty {
                            renderedWord = Text(word.text).foregroundColor(highlightColor)
                                .underline(true, color: .white.opacity(0.2)) // Subtle underline for active word
                        } else if word.text.hasPrefix(typedPrefix) {
                            let remaining = String(word.text.dropFirst(typedPrefix.count))
                            renderedWord = Text(typedPrefix).foregroundColor(highlightColor)
                                + Text(remaining).foregroundColor(.white.opacity(0.4))
                        } else {
                            // Typed more/different than base word
                            renderedWord = Text(typedPrefix).foregroundColor(highlightColor)
                                .strikethrough(true, color: highlightColor.opacity(0.5)) // Subtle strike if way off
                        }
                        
                    } else {
                        // Upcoming words
                        renderedWord = Text(word.text)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    // Add space between words
                    let space = Text(" ")
                    
                    return result + renderedWord + space
                }
                .font(.system(size: 32, weight: .regular, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineSpacing(16)
                // Smooth transition as text updates
                .animation(.easeInOut(duration: 0.1), value: engine.currentInput)
                .animation(.easeInOut(duration: 0.3), value: engine.currentWordIndex)
            }
        }
        // Force focus when tapped
        .onTapGesture {
            isFocused = true
        }
    }
    
    // MARK: - Results
    private var resultsView: some View {
        VStack(spacing: 30) {
            Text("Focus Complete")
                .font(FlowTypography.headingFont(size: 24))
                .foregroundStyle(.white.opacity(0.5))
            
            HStack(spacing: 60) {
                metricDisplay(value: "\(engine.wpm)", label: "WPM")
                metricDisplay(value: "\(engine.accuracy)%", label: "ACCURACY")
                metricDisplay(value: "\(engine.errors)", label: "ERRORS")
            }
            .opacity(0)
            .animation(.easeIn(duration: 0.8).delay(0.2), value: engine.state)
        }
        .transition(.opacity)
        .onAppear {
            // Trigger animation
            engine.state = .finished // Re-assert to trigger the opacity animation binding if needed, though state already finished
        }
    }
    
    private func metricDisplay(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(FlowTypography.headingFont(size: 48))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.numericText())
            
            Text(label)
                .font(FlowTypography.captionFont(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(2)
        }
    }
}
