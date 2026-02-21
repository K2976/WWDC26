# Flow — macOS Cognitive Load & Focus Companion

**Flow** is a macOS app that visualizes cognitive load in real time — turning attention into something you can see, feel, and gently recover from. Designed for the Swift Student Challenge 2026, it acts not as a productivity tracker, but as a mirror for attention.

The experience is intentionally calm, minimal, and premium — designed to feel unmistakably Apple-like. Every animation, sound, and interaction is purposeful.

## ✨ Features

- **Living Focus Orb**: A dynamic orb that breathes, pulses, glows, and distorts based on your current cognitive load. Rendered entirely with SwiftUI Canvas.
- **Dynamic Color System**: UI colors shift smoothly across a perceptual HSB spectrum from calm (deep blue) to overloaded (red).
- **Real-Time Attention Tracking**: Log distractions (App Switches, Notifications, Mind Wandering) to see their immediate impact on your cognitive load.
- **Focus Mode**: A dedicated mode featuring a 4-7-8 breathing guide, accelerating cognitive recovery while minimizing distractions.
- **Smart Recovery**: Automatic guided breathing interventions when your cognitive load exceeds healthy limits.
- **Session Summaries**: Beautifully crafted session cards providing insights, emotional reflections, and estimated recovery costs.
- **7-Day History**: Keep track of your average & peak cognitive load across the week.
- **Subtle Haptics & Audio**: Programmatically generated ambient audio and CoreHaptics provide non-intrusive feedback.
- **Local Keyboard Shortcuts**: Sandbox-safe shortcuts for quick logging (Space to log mind wandering, ⌘1/2/3 for events, ⌘F for focus toggle).
- **Built-in Demo Mode**: On first launch, the app automatically simulates a session (fading out upon interaction) so you can quickly see the full visual range.

## 🛠️ Technology Stack

- **Language:** Swift 6
- **Framework:** SwiftUI
- **Target:** macOS 15+ (Compatible with macOS 26 / Xcode 26)
- **Project Format:** Xcode App Playground (`.swiftpm`)
- **Key APIs:** Swift Charts, Canvas + TimelineView, AVFoundation, CoreHaptics

## 🚀 How to Run the Project

Since Flow is built as an **Xcode App Playground (`.swiftpm`)**, the setup process is extremely simple. No external dependencies or package managers are required.

### Prerequisites
- A Mac running macOS 15 or later.
- Xcode 16 or later (ideally Xcode 26 beta for the WWDC26 target).

### Steps
1. **Open the Project:**
   - Locate the `Flow.swiftpm` folder inside the project directory.
   - Double-click the `Flow.swiftpm` folder, or open Xcode and select **File > Open**, then choose `Flow.swiftpm`.
   
2. **Select the Target:**
   - In Xcode, ensure the **Flow** target is selected at the top in the scheme menu.
   - Choose **My Mac** as the run destination.

3. **Build and Run:**
   - Press `Cmd + R` (⌘R) or click the **Play** button in the Xcode toolbar.
   - The app will compile quickly and launch on your Mac.

### Exploration Tips
- **Demo Mode**: When you first run the app and complete the short onboarding, wait a few seconds without clicking anything. Flow will automatically inject simulated events to quickly demonstrate the orb's color, pulse, and distortion changes.
- **Quick Logging**: Use `Cmd+1`, `Cmd+2`, or `Cmd+3` to quickly log distraction events while the app window is focused.
- **Recovery**: Rapidly log events to push your score over 85 to see the automatic Smart Recovery breathing guide.
