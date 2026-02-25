import SwiftUI
import SceneKit

// MARK: - Globe Scene View (NSViewRepresentable)

struct GlobeSceneView: NSViewRepresentable {
    let score: Double

    func makeNSView(context: Context) -> GlobePlanetView {
        let v = GlobePlanetView()
        v.setupScene(score: score)
        return v
    }

    func updateNSView(_ nsView: GlobePlanetView, context: Context) {
        nsView.updateScore(score)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {}
}

// MARK: - Custom SCNView with Mouse Interaction

@MainActor
final class GlobePlanetView: SCNView {

    // MARK: Nodes
    private var planetNode: SCNNode!
    private var planetMaterial: SCNMaterial!
    private var lastAppliedScore: Double = -1

    // MARK: Rotation state
    private var orientation = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
    private let autoYawRate: Float = Float(.pi * 2 / 90.0)

    // Drag state
    private var dragging = false
    private var lastDragPt: NSPoint = .zero
    private var lastDragTS: TimeInterval = 0
    private var velYaw:   Float = 0
    private var velPitch: Float = 0

    // Frame loop
    private var frameTimer: Timer?
    private var lastTick:   CFTimeInterval = 0

    // MARK: – Setup ────────────────────────────────────────────────────────────

    func setupScene(score: Double) {
        antialiasingMode    = .multisampling4X
        allowsCameraControl = false
        showsStatistics     = false
        backgroundColor     = .clear

        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        self.scene = scene

        addCamera(to: scene)
        addLights(to: scene)
        addPlanet(to: scene, score: score)
        startLoop()
    }

    // MARK: – Score Update ─────────────────────────────────────────────────────

    func updateScore(_ score: Double) {
        // Only regenerate texture when the score changes meaningfully (>2 points)
        guard abs(score - lastAppliedScore) > 2.0 else { return }
        lastAppliedScore = score
        planetMaterial?.diffuse.contents = Self.checkerTexture(score: score)
    }

    // MARK: – Scene Building ───────────────────────────────────────────────────

    private func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 38
        cam.zNear = 0.1
        cam.zFar  = 100

        let node = SCNNode()
        node.camera   = cam
        node.position = SCNVector3(0, 0, 5.5)
        scene.rootNode.addChildNode(node)
    }

    private func addLights(to scene: SCNScene) {
        let amb = SCNNode()
        amb.light           = SCNLight()
        amb.light!.type      = .ambient
        amb.light!.intensity = 260
        amb.light!.color     = NSColor.white
        scene.rootNode.addChildNode(amb)

        let main = SCNNode()
        main.light           = SCNLight()
        main.light!.type      = .directional
        main.light!.intensity = 820
        main.light!.color     = NSColor(white: 0.92, alpha: 1)
        main.eulerAngles      = SCNVector3(-0.6, -0.8, 0)
        scene.rootNode.addChildNode(main)

        let fill = SCNNode()
        fill.light           = SCNLight()
        fill.light!.type      = .directional
        fill.light!.intensity = 90
        fill.light!.color     = NSColor(calibratedRed: 0.5, green: 0.65, blue: 1.0, alpha: 1)
        fill.eulerAngles      = SCNVector3(0, Float.pi * 0.65, 0)
        scene.rootNode.addChildNode(fill)
    }

    private func addPlanet(to scene: SCNScene, score: Double) {
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 80

        let mat = SCNMaterial()
        mat.diffuse.contents  = Self.checkerTexture(score: score)
        mat.specular.contents = NSColor(white: 0.18, alpha: 1)
        mat.shininess         = 10
        mat.lightingModel     = .phong
        sphere.firstMaterial  = mat

        planetMaterial = mat
        lastAppliedScore = score

        planetNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(planetNode)
    }

    // MARK: – Score-Reactive Checker Texture ───────────────────────────────────

    /// Generates a 2048×1024 equirectangular checker texture tinted with
    /// the cognitive-load color from FlowColors.
    private static func checkerTexture(score: Double) -> NSImage {
        let W = 2048, H = 1024
        let img = NSImage(size: CGSize(width: W, height: H))
        img.lockFocus()
        defer { img.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

        // Resolve the score color to RGBA components
        let swiftColor = FlowColors.color(for: score)
        let resolved = NSColor(swiftColor).usingColorSpace(.deviceRGB)
            ?? NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.9, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Dark cells: use a very dark version of the score color
        let darkCell = CGColor(red: r * 0.12, green: g * 0.12, blue: b * 0.12, alpha: 1)
        // Light cells: the score color at full brightness
        let lightCell = CGColor(red: r, green: g, blue: b, alpha: 1)
        // Grid lines: mid-tone of the score color
        let gridLine = CGColor(red: r * 0.45, green: g * 0.45, blue: b * 0.45, alpha: 0.8)

        // Fill background with dark cells
        ctx.setFillColor(darkCell)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        // 16×8 checker grid
        let cols = 16, rows = 8
        let cW = CGFloat(W) / CGFloat(cols)
        let cH = CGFloat(H) / CGFloat(rows)

        for row in 0..<rows {
            for col in 0..<cols {
                guard (row + col) % 2 == 0 else { continue }
                ctx.setFillColor(lightCell)
                ctx.fill(CGRect(x: CGFloat(col) * cW + 1.5, y: CGFloat(row) * cH + 1.5,
                                width: cW - 3, height: cH - 3))
            }
        }

        // Thin grid lines
        ctx.setStrokeColor(gridLine)
        ctx.setLineWidth(2.5)
        for c in 0...cols {
            let x = CGFloat(c) * cW
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: CGFloat(H)))
        }
        for row in 0...rows {
            let y = CGFloat(row) * cH
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: CGFloat(W), y: y))
        }
        ctx.strokePath()

        return img
    }

    // MARK: – Frame Loop ───────────────────────────────────────────────────────

    private func startLoop() {
        lastTick = CACurrentMediaTime()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(frameTimer!, forMode: .common)
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt  = Float(now - lastTick)
        lastTick = now
        guard dt > 0 && dt < 0.1 else { return }
        if dragging { return }

        let speed = max(abs(velYaw), abs(velPitch))
        if speed > 0.005 {
            let friction: Float = pow(0.88, dt * 60)
            velYaw   *= friction
            velPitch *= friction
            applyDelta(yaw: velYaw * dt, pitch: velPitch * dt)
        } else {
            velYaw   = 0
            velPitch = 0
            applyDelta(yaw: autoYawRate * dt, pitch: 0)
        }
    }

    private func applyDelta(yaw: Float, pitch: Float) {
        if yaw != 0 {
            orientation = simd_quatf(angle: yaw, axis: simd_float3(0, 1, 0)) * orientation
        }
        if pitch != 0 {
            orientation = simd_quatf(angle: pitch, axis: simd_float3(1, 0, 0)) * orientation
        }
        planetNode?.simdOrientation = orientation
    }

    // MARK: – Mouse Events ─────────────────────────────────────────────────────

    override func mouseDown(with event: NSEvent) {
        let loc  = convert(event.locationInWindow, from: nil)
        let hits = hitTest(loc, options: nil)
        guard !hits.isEmpty else {
            window?.performDrag(with: event)
            return
        }
        dragging   = true
        lastDragPt = loc
        lastDragTS = event.timestamp
        velYaw     = 0
        velPitch   = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let dx  = Float(loc.x - lastDragPt.x)
        let dy  = Float(loc.y - lastDragPt.y)
        let dt  = Float(max(event.timestamp - lastDragTS, 1.0 / 120.0))
        let sens: Float = 0.007
        applyDelta(yaw: -dx * sens, pitch: dy * sens)
        let a: Float = 0.4
        velYaw   = velYaw   * (1 - a) + (-dx * sens / dt) * a
        velPitch = velPitch * (1 - a) + ( dy * sens / dt) * a
        lastDragPt = loc
        lastDragTS = event.timestamp
        
    }

    override func mouseUp(with event: NSEvent) {
        dragging = false
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            frameTimer?.invalidate()
            frameTimer = nil
        }
    }
}
