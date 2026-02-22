import SwiftUI

// MARK: - Recovery View (Smart Reset)

struct RecoveryView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Binding var isPresented: Bool
    
    @State private var isRecovering = false
    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.8
    @State private var recoveryProgress: Double = 0
    @State private var showMessage = true
    
    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isRecovering {
                        withAnimation { isPresented = false }
                    }
                }
            
            VStack(spacing: 24) {
                if !isRecovering {
                    // Pre-recovery message
                    VStack(spacing: 16) {
                        Image(systemName: "wind")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange.opacity(0.7))
                        
                        Text("Your mind is overloaded")
                            .font(FlowTypography.labelFont(size: 18))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Text("Take a moment. Nothing is urgent enough to burn out for.")
                            .font(FlowTypography.bodyFont(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button {
                            startRecovery()
                        } label: {
                            Text("Reset Attention")
                                .font(FlowTypography.labelFont(size: 15))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(FlowColors.color(for: 30).opacity(0.5))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .colorScheme(.dark)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Recovery breathing animation
                    VStack(spacing: 20) {
                        ZStack {
                            // Breathing circle
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            FlowColors.color(for: 25).opacity(0.6),
                                            FlowColors.color(for: 25).opacity(0.1)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 60
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .scaleEffect(breathScale)
                                .opacity(breathOpacity)
                            
                            // Progress ring
                            Circle()
                                .trim(from: 0, to: recoveryProgress)
                                .stroke(
                                    FlowColors.color(for: 25).opacity(0.5),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .frame(width: 148, height: 148)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text("Resetting...")
                            .font(FlowTypography.bodyFont(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(FlowAnimation.viewTransition, value: isRecovering)
    }
    
    private func startRecovery() {
        isRecovering = true
        engine.triggerAcceleratedDecay(amount: max(engine.score - 20, 0), duration: 10)
        
        // Breathing animation over 10 seconds (5 cycles of 2 seconds)
        let cycleDuration: Double = 2.0
        let totalDuration: Double = 10.0
        
        // Animate breathing
        func breathCycle() {
            withAnimation(.easeInOut(duration: cycleDuration / 2)) {
                breathScale = 1.2
                breathOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration / 2) {
                withAnimation(.easeInOut(duration: cycleDuration / 2)) {
                    breathScale = 0.85
                    breathOpacity = 0.5
                }
            }
        }
        
        // Run 5 cycles
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration * Double(i)) {
                breathCycle()
            }
        }
        
        // Progress animation
        withAnimation(.linear(duration: totalDuration)) {
            recoveryProgress = 1.0
        }
        
        // Complete after 10 seconds — ensure score is at baseline
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            engine.markReset()
            engine.setScore(20)
            withAnimation(FlowAnimation.viewTransition) {
                isPresented = false
            }
        }
    }
}
