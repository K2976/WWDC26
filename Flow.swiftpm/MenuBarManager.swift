import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Menu Bar Manager (macOS Only)

@MainActor
@Observable
final class MenuBarManager {
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    var isAvailable: Bool = false
    
    func setup(engine: CognitiveLoadEngine, sessionManager: SessionManager, simulation: SimulationManager, audio: AudioManager, haptics: HapticsManager) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = item.button {
            let imageView = NSHostingView(rootView:
                MiniOrbView(score: engine.animatedScore, size: 18)
            )
            imageView.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
            button.addSubview(imageView)
            button.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
            button.action = #selector(NSApplication.shared.togglePopover(_:))
        }
        
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 280, height: 320)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(haptics: haptics)
                .environment(engine)
                .environment(sessionManager)
                .environment(simulation)
                .environment(audio)
        )
        
        self.statusItem = item
        self.popover = pop
        self.isAvailable = true
    }
    
    func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - NSApplication Extension (for menubar toggle)

extension NSApplication {
    @objc func togglePopover(_ sender: Any?) {
        // Placeholder — actual toggle handled by manager
    }
}

// MARK: - Popover View

struct MenuBarPopoverView: View {
    @Environment(CognitiveLoadEngine.self) private var engine
    @Environment(SimulationManager.self) private var simulation
    
    let haptics: HapticsManager
    
    var body: some View {
        VStack(spacing: 16) {
            FocusOrbView(score: engine.animatedScore, size: 100)
            
            Text("\(Int(engine.animatedScore))")
                .font(FlowTypography.scoreFont(size: 36))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.numericText())
            
            Text(engine.state.label)
                .font(FlowTypography.labelFont(size: 14))
                .foregroundStyle(FlowColors.color(for: engine.animatedScore))
            
            Divider()
                .background(.white.opacity(0.1))
            
            HStack(spacing: 8) {
                ForEach(AttentionEvent.allCases) { event in
                    Button {
                        simulation.userHasInteracted = true
                        engine.logEvent(event)
                        haptics.playEventFeedback()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: event.symbol)
                                .font(.system(size: 12))
                            Text("+\(Int(event.loadIncrease))")
                                .font(FlowTypography.captionFont(size: 9))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Text("Open Flow")
                    .font(FlowTypography.bodyFont(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 280, height: 320)
        .background(
            FlowColors.backgroundColor(for: engine.animatedScore)
        )
    }
}

#else

// MARK: - Menu Bar Manager (Stub for iOS/iPadOS)

@MainActor
@Observable
final class MenuBarManager {
    var isAvailable: Bool = false
    
    func setup(engine: CognitiveLoadEngine, sessionManager: SessionManager, simulation: SimulationManager, audio: AudioManager, haptics: HapticsManager) {
        // Menu bar not available on iOS/iPadOS
    }
    
    func togglePopover() {
        // No-op on iOS/iPadOS
    }
}

#endif
