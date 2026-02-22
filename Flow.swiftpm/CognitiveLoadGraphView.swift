import SwiftUI
import Charts

// MARK: - Cognitive Load Graph

struct CognitiveLoadGraphView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ATTENTION TIMELINE")
                .font(FlowTypography.captionFont(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
            
            Chart {
                // Main line
                ForEach(engine.history) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Load", snapshot.score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                FlowColors.color(for: 30),
                                FlowColors.color(for: 60),
                                FlowColors.color(for: 90)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Load", snapshot.score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                FlowColors.color(for: engine.animatedScore).opacity(0.15),
                                FlowColors.color(for: engine.animatedScore).opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
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
                ForEach(engine.events.suffix(20)) { event in
                    PointMark(
                        x: .value("Time", event.timestamp),
                        y: .value("Load", event.scoreAfter)
                    )
                    .foregroundStyle(FlowColors.color(for: event.scoreAfter))
                    .symbolSize(20)
                }
                
                // Reset markers — vertical dotted lines where recovery resets happened
                ForEach(engine.resetTimestamps, id: \.self) { resetTime in
                    RuleMark(x: .value("Reset", resetTime))
                        .foregroundStyle(.white.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .center) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 7))
                                Text("Reset")
                                    .font(FlowTypography.captionFont(size: 8))
                            }
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.06))
                            )
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(FlowTypography.captionFont(size: 9))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: .dateTime.minute().second())
                        .font(FlowTypography.captionFont(size: 9))
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
            .frame(height: 140)
        }
    }
}
