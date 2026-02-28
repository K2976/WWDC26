// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flow",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "Flow",
            path: ".",
            sources: [
                "FlowApp.swift",
                "DesignSystem.swift",
                "AttentionEvent.swift",
                "CognitiveLoadEngine.swift",
                "SessionManager.swift",
                "SimulationManager.swift",
                "DemoManager.swift",
                "RealEventDetector.swift",
                "AudioManager.swift",
                "HapticsManager.swift",
                "ScienceInsights.swift",
                "FocusOrbView.swift",
                "GlobeView.swift",
                "MiniOrbView.swift",
                "OnboardingView.swift",
                "DashboardView.swift",
                "CognitiveLoadGraphView.swift",
                "FocusModeView.swift",
                "RecoveryView.swift",
                "SessionSummaryView.swift",
                "HistoryStripView.swift",
                "MenuBarManager.swift",
                "CompactFlipClockView.swift",
                "ColdLoadingView.swift",
                "SessionStartView.swift",
                "GuideOverlayView.swift"
            ]
        )
    ]
)
