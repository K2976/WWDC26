import SwiftUI

// MARK: - History Strip View (7-Day)

struct HistoryStripView: View {
    @Environment(SessionManager.self) private var sessionManager
    
    @State private var selectedDay: DaySummary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST 7 DAYS")
                .font(FlowTypography.captionFont(size: 10))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
            
            HStack(spacing: 6) {
                ForEach(sessionManager.weekHistory) { day in
                    daySquare(day)
                }
            }
            
            // Day detail popover
            if let day = selectedDay {
                dayDetail(day)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(FlowAnimation.viewTransition, value: selectedDay?.id)
    }
    
    private func daySquare(_ day: DaySummary) -> some View {
        let isSelected = selectedDay?.id == day.id
        let color = FlowColors.color(for: day.averageScore)
        
        return Button {
            withAnimation {
                selectedDay = selectedDay?.id == day.id ? nil : day
            }
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isSelected ? 0.8 : 0.5))
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(isSelected ? 0.3 : 0.05), lineWidth: isSelected ? 1.5 : 0.5)
                    )
                    .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6)
                
                Text(dayLabel(day.date))
                    .font(FlowTypography.captionFont(size: 9))
                    .foregroundStyle(.white.opacity(isSelected ? 0.6 : 0.25))
            }
        }
        .buttonStyle(.plain)
    }
    
    private func dayDetail(_ day: DaySummary) -> some View {
        let sessions = sessionManager.savedSessions(for: day.date)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Day overview
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fullDayLabel(day.date))
                        .font(FlowTypography.bodyFont(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("Avg: \(Int(day.averageScore)) • Peak: \(Int(day.peakScore))")
                        .font(FlowTypography.captionFont(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.eventCount) events")
                        .font(FlowTypography.captionFont(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("\(Int(day.totalMinutes))m tracked")
                        .font(FlowTypography.captionFont(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            
            // Saved sessions for this day
            if !sessions.isEmpty {
                Divider()
                    .background(.white.opacity(0.08))
                
                ForEach(sessions) { session in
                    HStack(spacing: 10) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(FlowColors.color(for: session.averageScore).opacity(0.7))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.name ?? "Session")
                                .font(FlowTypography.bodyFont(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            let duration = Int(session.endTime.timeIntervalSince(session.startTime))
                            let mins = duration / 60
                            let secs = duration % 60
                            Text("\(mins)m \(secs)s • Avg: \(Int(session.averageScore)) • Peak: \(Int(session.peakScore))")
                                .font(FlowTypography.captionFont(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        
                        Spacer()
                        
                        Text("\(session.eventCount) events")
                            .font(FlowTypography.captionFont(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.04))
        )
    }
    
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func fullDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
