import SwiftUI

// MARK: - Session Start View (Attention Level Picker)

struct SessionStartView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Binding var isPresented: Bool
    
    @State private var showPrompt = false
    @State private var showOrbs = false
    @State private var selectedLevel: Int? = nil
    @State private var showColdLoading = false
    
    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            if !showColdLoading {
                VStack(spacing: 36) {
                    Spacer()
                    
                    // Orb preview
                    FocusOrbView(
                        score: selectedLevel != nil
                            ? [10.0, 30, 50, 70, 90][selectedLevel! - 1]
                            : 30,
                        size: 160
                    )
                    
                    // Prompt
                    if showPrompt {
                        VStack(spacing: 20) {
                            Text("How focused are you right now?")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text("Set your starting attention level")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            // 5 orb choices
                            HStack(spacing: 20) {
                                ForEach(1...5, id: \.self) { level in
                                    orbOption(level: level)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    Spacer()
                }
                .padding(40)
                .transition(.opacity)
            }
            
            // Loading overlay
            if showColdLoading {
                ColdLoadingView(isPresented: $showColdLoading)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.4), value: showColdLoading)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
                showPrompt = true
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.6)) {
                showOrbs = true
            }
        }
    }
    
    @ViewBuilder
    private func orbOption(level: Int) -> some View {
        let isSelected = selectedLevel == level
        let labels = ["Calm", "Relaxed", "Moderate", "Elevated", "Overloaded"]
        let scores: [Double] = [10, 30, 50, 70, 90]
        let score = scores[level - 1]
        let label = labels[level - 1]
        let color = FlowColors.color(for: score)
        
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedLevel = level
            }
            
            // Set the initial score for the new session
            engine.setInitialScore(score)
            
            // Show loading, then dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showColdLoading = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showColdLoading = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isPresented = false
                    }
                }
            }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color, color.opacity(0.4)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: isSelected ? 48 : 40, height: isSelected ? 48 : 40)
                    .shadow(color: color.opacity(isSelected ? 0.8 : 0.3), radius: isSelected ? 15 : 5)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 0.4 : 0), lineWidth: 2)
                    )
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 0.9 : 0.4))
            }
        }
        .buttonStyle(.plain)
        .opacity(showOrbs ? 1 : 0)
        .animation(.easeIn(duration: 0.4).delay(Double(level) * 0.1), value: showOrbs)
    }
}
