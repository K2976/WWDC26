import SwiftUI

// MARK: - Compact Flip Clock View

struct CompactFlipClockView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    let date: Date
    
    var hours: Int {
        Calendar.current.component(.hour, from: date)
    }
    
    var minutes: Int {
        Calendar.current.component(.minute, from: date)
    }
    
    var body: some View {
        let isHighLoad = engine.score > 50
        
        HStack(spacing: 4) {
            // Hours
            HStack(spacing: 2) {
                FlipDigit(value: hours / 10)
                FlipDigit(value: hours % 10)
            }
            
            Text(":")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .opacity(0.45)
                .offset(y: -2)
            
            // Minutes
            HStack(spacing: 4) {
                FlipDigit(value: minutes / 10)
                FlipDigit(value: minutes % 10)
            }
        }
        .opacity(isHighLoad ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: isHighLoad)
    }
}

// MARK: - Flip Digit

struct FlipDigit: View {
    let value: Int
    @State private var currentValue: Int
    @State private var nextValue: Int
    @State private var flipPhase: Double = 0
    @State private var isFlipping = false
    
    init(value: Int) {
        self.value = value
        self._currentValue = State(initialValue: value)
        self._nextValue = State(initialValue: value)
    }
    
    var body: some View {
        ZStack {
            // BACK layer (static during flip)
            VStack(spacing: 1) {
                HalfDigit(value: nextValue, isTop: true)
                HalfDigit(value: currentValue, isTop: false)
            }
            
            // FRONT layer (animating flaps)
            VStack(spacing: 1) {
                HalfDigit(value: flipPhase < 0.5 ? currentValue : nextValue, isTop: true)
                    .rotation3DEffect(
                        .degrees(flipPhase < 0.5 ? -90 * (flipPhase * 2) : 0),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.5
                    )
                    .opacity(flipPhase < 0.5 ? 1 : 0) // Hide when past 90 degrees
                
                HalfDigit(value: flipPhase >= 0.5 ? nextValue : currentValue, isTop: false)
                    .rotation3DEffect(
                        .degrees(flipPhase >= 0.5 ? 90 * (1 - (flipPhase - 0.5) * 2) : 90),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.5
                    )
                    .opacity(flipPhase >= 0.5 ? 1 : 0) // Hide when before 90 degrees
            }
        }
        .opacity(isFlipping ? 0.75 : 0.55) // Brief opacity bump during flip, default 55%
        .onChange(of: value) { _, newValue in
            guard newValue != currentValue else { return }
            nextValue = newValue
            isFlipping = true
            
            withAnimation(.linear(duration: 0.25)) {
                flipPhase = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                currentValue = newValue
                flipPhase = 0
                isFlipping = false
            }
        }
    }
}

// MARK: - Half Digit

struct HalfDigit: View {
    let value: Int
    let isTop: Bool
    
    let width: CGFloat = 38
    let fullHeight: CGFloat = 68
    let halfHeight: CGFloat = 34
    
    var body: some View {
        ZStack {
            Color(white: 0.08).opacity(0.8) // Transparent near-black background
            
            Text("\(value)")
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: width, height: fullHeight)
                .offset(y: isTop ? halfHeight/2 : -halfHeight/2)
        }
        .frame(width: width, height: halfHeight)
        .clipped()
        .cornerRadius(3.0)
    }
}
