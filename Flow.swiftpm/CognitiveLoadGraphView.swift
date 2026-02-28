import SwiftUI
import Charts

// MARK: - Cognitive Load Graph

struct CognitiveLoadGraphView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Environment(\.flowScale) private var s
    
    // Throttled data — updates every second
    @State private var displayHistory: [LoadSnapshot] = []
    @State private var displayEvents: [AttentionEventRecord] = []
    @State private var displayResets: [Date] = []
    @State private var updateTimer: Timer?
    @State private var graphReady = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            Text("ATTENTION TIMELINE")
                .font(FlowTypography.captionFont(size: 11 * s))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
            
            Chart {
                // Main line only — no AreaMark for performance
                ForEach(displayHistory) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Load", snapshot.score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                FlowColors.color(for: 0),
                                FlowColors.color(for: 25),
                                FlowColors.color(for: 50),
                                FlowColors.color(for: 70),
                                FlowColors.color(for: 85),
                                FlowColors.color(for: 100)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
                
                // Threshold lines
                RuleMark(y: .value("Moderate", 50))
                    .foregroundStyle(.white.opacity(0.1))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                
                RuleMark(y: .value("High", 70))
                    .foregroundStyle(.orange.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                
                RuleMark(y: .value("Overloaded", 85))
                    .foregroundStyle(.red.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                
                // Event markers
                ForEach(displayEvents) { event in
                    PointMark(
                        x: .value("Time", event.timestamp),
                        y: .value("Load", event.scoreAfter)
                    )
                    .foregroundStyle(FlowColors.color(for: event.scoreAfter))
                    .symbolSize(20)
                }
                
                // Reset markers
                ForEach(displayResets, id: \.self) { resetTime in
                    RuleMark(x: .value("Reset", resetTime))
                        .foregroundStyle(.white.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .center) {
                            HStack(spacing: 3 * s) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 7 * s))
                                Text("Reset")
                                    .font(FlowTypography.captionFont(size: 8 * s))
                            }
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 4 * s)
                            .padding(.vertical, 2 * s)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.06))
                            )
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: xDomain)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(FlowTypography.captionFont(size: 9 * s))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(FlowTypography.captionFont(size: 9 * s))
                        .foregroundStyle(.white.opacity(0.3))
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.05))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(.white.opacity(0.02))
                    .border(.white.opacity(0.05), width: 0.5)
            }
            .frame(height: 140 * s)
            .opacity(graphReady ? 1 : 0)
            .animation(.easeIn(duration: 0.4), value: graphReady)
        }
        .onAppear { startThrottledUpdates() }
        .onDisappear { updateTimer?.invalidate() }
    }
    
    // X-axis domain — always shows at least a 60-second window so the chart never collapses
    private var xDomain: ClosedRange<Date> {
        let now = DemoManager.sharedCurrentDate
        if let earliest = displayHistory.first?.timestamp {
            let start = min(earliest, now.addingTimeInterval(-60))
            return start...now
        }
        return now.addingTimeInterval(-60)...now
    }
    
    // Refresh chart data every second; mark ready once data exists
    private func startThrottledUpdates() {
        refreshDisplayData()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                refreshDisplayData()
            }
        }
    }
    
    private func refreshDisplayData() {
        displayHistory = Array(engine.history.suffix(80))
        displayEvents = Array(engine.events.suffix(15))
        displayResets = engine.resetTimestamps
        if !displayHistory.isEmpty && !graphReady {
            graphReady = true
        }
    }
}
