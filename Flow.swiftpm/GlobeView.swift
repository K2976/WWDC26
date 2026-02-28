import SwiftUI
import SceneKit

#if os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#endif

// MARK: - Globe Scene View

struct GlobeSceneView: PlatformViewRepresentable {
    let score: Double

    #if os(macOS)
    func makeNSView(context: Context) -> GlobePlanetView {
        let v = GlobePlanetView()
        v.setupScene(score: score)
        return v
    }

    func updateNSView(_ nsView: GlobePlanetView, context: Context) {
        nsView.updateScore(score)
    }
    #else
    func makeUIView(context: Context) -> GlobePlanetView {
        let v = GlobePlanetView()
        v.setupScene(score: score)
        return v
    }

    func updateUIView(_ uiView: GlobePlanetView, context: Context) {
        uiView.updateScore(score)
    }
    #endif

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
    private var lastDragPt: CGPoint = .zero
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
        scene.background.contents = PlatformColor.clear
        self.scene = scene

        addCamera(to: scene)
        addLights(to: scene)
        addPlanet(to: scene, score: score)
        startLoop()
    }

    // MARK: – Score Update ─────────────────────────────────────────────────────

    func updateScore(_ score: Double) {
        guard abs(score - lastAppliedScore) > 1.0 else { return }
        lastAppliedScore = score
        
        let targetColor = FlowColors.color(for: score)
        #if os(macOS)
        let resolved = PlatformColor(targetColor).usingColorSpace(.deviceRGB) ?? PlatformColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1)
        #else
        let resolved = PlatformColor(targetColor)
        #endif
        
        // Transition colors for nodes and arcs
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0 // Smooth color transition
        
        planetNode?.childNodes.forEach { node in
            if node.name == "dot" {
                node.geometry?.firstMaterial?.diffuse.contents = resolved
                node.geometry?.firstMaterial?.emission.contents = resolved
            } else if node.name == "arc" {
                node.geometry?.firstMaterial?.diffuse.contents = resolved.withAlphaComponent(0.6)
                node.geometry?.firstMaterial?.emission.contents = resolved.withAlphaComponent(0.4)
            }
        }
        
        SCNTransaction.commit()
    }

    // MARK: – Scene Building ───────────────────────────────────────────────────

    private func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 38
        cam.zNear = 0.1
        cam.zFar  = 100
        
        // Perspective adjustment aids in depth feel
        let node = SCNNode()
        node.camera   = cam
        node.position = SCNVector3(0, 0, 5.5)
        scene.rootNode.addChildNode(node)
    }

    private func addLights(to scene: SCNScene) {
        let amb = SCNNode()
        amb.light           = SCNLight()
        amb.light!.type      = .ambient
        // Increase ambient slightly so nodes don't go entirely black on back half
        amb.light!.intensity = 350
        amb.light!.color     = PlatformColor.white
        scene.rootNode.addChildNode(amb)

        let main = SCNNode()
        main.light           = SCNLight()
        main.light!.type      = .directional
        main.light!.intensity = 600
        main.light!.color     = PlatformColor(white: 0.85, alpha: 1)
        main.eulerAngles      = SCNVector3(-0.6, -0.8, 0)
        scene.rootNode.addChildNode(main)
    }

    private func addPlanet(to scene: SCNScene, score: Double) {
        planetNode = SCNNode()
        
        let currentSwiftColor = FlowColors.color(for: score)
        #if os(macOS)
        let resolved = PlatformColor(currentSwiftColor).usingColorSpace(.deviceRGB) ?? PlatformColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1)
        #else
        let resolved = PlatformColor(currentSwiftColor)
        #endif
        
        let R: Float = 1.05
        let freq = 5  // Subdivision frequency → ~252 vertices
        
        // ── 1. Icosahedron base geometry ──────────────────────────────────────
        let t: Float = (1.0 + sqrt(5.0)) / 2.0
        let icoVerts: [(Float, Float, Float)] = [
            (-1,  t,  0), ( 1,  t,  0), (-1, -t,  0), ( 1, -t,  0),
            ( 0, -1,  t), ( 0,  1,  t), ( 0, -1, -t), ( 0,  1, -t),
            ( t,  0, -1), ( t,  0,  1), (-t,  0, -1), (-t,  0,  1)
        ]
        let icoFaces: [(Int, Int, Int)] = [
            (0,11,5),  (0,5,1),   (0,1,7),   (0,7,10),  (0,10,11),
            (1,5,9),   (5,11,4),  (11,10,2), (10,7,6),  (7,1,8),
            (3,9,4),   (3,4,2),   (3,2,6),   (3,6,8),   (3,8,9),
            (4,9,5),   (2,4,11),  (6,2,10),  (8,6,7),   (9,8,1)
        ]
        
        // ── 2. Subdivide each face → unique vertices + edges ──────────────────
        var vertexMap: [String: Int] = [:]
        var points: [SCNVector3] = []
        var edgeSet: Set<String> = []
        
        func vKey(_ x: Float, _ y: Float, _ z: Float) -> String {
            let p: Float = 10000
            return "\(round(x*p)),\(round(y*p)),\(round(z*p))"
        }
        
        func addVert(_ x: Float, _ y: Float, _ z: Float) -> Int {
            let len = sqrt(x*x + y*y + z*z)
            let nx = x / len * R, ny = y / len * R, nz = z / len * R
            let key = vKey(nx, ny, nz)
            if let idx = vertexMap[key] { return idx }
            let idx = points.count
            points.append(SCNVector3(nx, ny, nz))
            vertexMap[key] = idx
            return idx
        }
        
        func addEdge(_ a: Int, _ b: Int) {
            edgeSet.insert("\(min(a,b))-\(max(a,b))")
        }
        
        for face in icoFaces {
            let va = icoVerts[face.0]
            let vb = icoVerts[face.1]
            let vc = icoVerts[face.2]
            
            // Build grid[i][j] where i+j <= freq
            var grid: [[Int]] = []
            for i in 0...freq {
                var row: [Int] = []
                for j in 0...(freq - i) {
                    let fi = Float(i) / Float(freq)
                    let fj = Float(j) / Float(freq)
                    let fk = 1.0 - fi - fj
                    let x = fk * va.0 + fi * vb.0 + fj * vc.0
                    let y = fk * va.1 + fi * vb.1 + fj * vc.1
                    let z = fk * va.2 + fi * vb.2 + fj * vc.2
                    row.append(addVert(x, y, z))
                }
                grid.append(row)
            }
            
            // Add all triangulation edges
            for i in 0..<freq {
                for j in 0..<(freq - i) {
                    addEdge(grid[i][j],   grid[i][j+1])    // horizontal
                    addEdge(grid[i][j],   grid[i+1][j])    // down
                    addEdge(grid[i][j+1], grid[i+1][j])    // diagonal
                }
            }
        }
        
        // ── 3. Create dot nodes ───────────────────────────────────────────────
        let dotGeom = SCNSphere(radius: 0.022)
        dotGeom.segmentCount = 12
        
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = resolved
        dotMat.emission.contents = resolved
        dotMat.emission.intensity = 0.8
        dotMat.transparent.contents = PlatformColor(white: 1.0, alpha: 0.9)
        dotMat.blendMode = .add
        dotMat.isDoubleSided = false
        dotGeom.firstMaterial = dotMat
        
        for point in points {
            let dotNode = SCNNode(geometry: dotGeom)
            dotNode.position = point
            dotNode.name = "dot"
            planetNode.addChildNode(dotNode)
        }
        
        // ── 4. Create edge lines ──────────────────────────────────────────────
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = resolved.withAlphaComponent(0.7)
        lineMat.emission.contents = resolved.withAlphaComponent(0.5)
        lineMat.transparent.contents = PlatformColor(white: 1.0, alpha: 0.7)
        lineMat.blendMode = .add
        
        for edgeKey in edgeSet {
            let parts = edgeKey.split(separator: "-")
            guard parts.count == 2,
                  let a = Int(parts[0]),
                  let b = Int(parts[1]) else { continue }
            
            let lineGeom = createLineGeometry(from: points[a], to: points[b], tubeRadius: 0.006)
            lineGeom.firstMaterial = lineMat
            
            let lineNode = SCNNode(geometry: lineGeom)
            lineNode.name = "arc"
            planetNode.addChildNode(lineNode)
        }
        
        scene.rootNode.addChildNode(planetNode)
        lastAppliedScore = score
    }
    
    // Distance helper
    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = Float(a.x) - Float(b.x)
        let dy = Float(a.y) - Float(b.y)
        let dz = Float(a.z) - Float(b.z)
        
        let dx2 = dx * dx
        let dy2 = dy * dy
        let dz2 = dz * dz
        
        return sqrt(dx2 + dy2 + dz2)
    }
    
    // Build a thin tube between two points (straight constellation line)
    private func createLineGeometry(from start: SCNVector3, to end: SCNVector3, tubeRadius: Float) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var indices: [UInt16] = []
        
        let sides = 4
        let pathPoints = [start, end]
        
        for i in 0..<pathPoints.count {
            let pt = pathPoints[i]
            let other = pathPoints[i == 0 ? 1 : 0]
            
            let dx = Float(other.x) - Float(pt.x)
            let dy = Float(other.y) - Float(pt.y)
            let dz = Float(other.z) - Float(pt.z)
            let len = sqrt(dx*dx + dy*dy + dz*dz)
            let fwd = SCNVector3(dx/len, dy/len, dz/len)
            
            var up = SCNVector3(0, 1, 0)
            if abs(Float(fwd.y)) > 0.99 { up = SCNVector3(1, 0, 0) }
            
            let uX = Float(up.x); let uY = Float(up.y); let uZ = Float(up.z)
            let fX = Float(fwd.x); let fY = Float(fwd.y); let fZ = Float(fwd.z)
            let right = SCNVector3(uY*fZ - uZ*fY, uZ*fX - uX*fZ, uX*fY - uY*fX)
            let rX = Float(right.x); let rY = Float(right.y); let rZ = Float(right.z)
            let rlen = sqrt(rX*rX + rY*rY + rZ*rZ)
            let nRight = SCNVector3(rX/rlen, rY/rlen, rZ/rlen)
            let nrX = Float(nRight.x); let nrY = Float(nRight.y); let nrZ = Float(nRight.z)
            let nUpX = fY*nrZ - fZ*nrY
            let nUpY = fZ*nrX - fX*nrZ
            let nUpZ = fX*nrY - fY*nrX
            let nUp = SCNVector3(nUpX, nUpY, nUpZ)
            
            for s in 0..<sides {
                let angle = Float(s) * 2.0 * Float.pi / Float(sides)
                let c = cos(angle) * tubeRadius
                let sAng = sin(angle) * tubeRadius
                let vx = Float(pt.x) + c * Float(nRight.x) + sAng * Float(nUp.x)
                let vy = Float(pt.y) + c * Float(nRight.y) + sAng * Float(nUp.y)
                let vz = Float(pt.z) + c * Float(nRight.z) + sAng * Float(nUp.z)
                vertices.append(SCNVector3(vx, vy, vz))
            }
            
            if i > 0 {
                let currRing = i * sides
                let prevRing = (i - 1) * sides
                for s in 0..<sides {
                    let nextS = (s + 1) % sides
                    indices.append(UInt16(prevRing + s))
                    indices.append(UInt16(currRing + s))
                    indices.append(UInt16(currRing + nextS))
                    indices.append(UInt16(prevRing + s))
                    indices.append(UInt16(currRing + nextS))
                    indices.append(UInt16(prevRing + nextS))
                }
            }
        }
        
        let src = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [src], elements: [element])
    }

    // (Texture generator removed for Point Cloud style)

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
            
            // Slow down the auto rotation to 120 seconds for full rotation
            // 2PI radians / 120s = 0.0523 rad/s
            let slowRate: Float = Float.pi * 2 / 120.0
            applyDelta(yaw: slowRate * dt, pitch: 0)
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

    // MARK: – Mouse / Touch Events ───────────────────────────────────────────────

    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let loc  = convert(event.locationInWindow, from: nil)
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
    override var mouseDownCanMoveWindow: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            frameTimer?.invalidate()
            frameTimer = nil
        }
    }
    #else
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let hits = hitTest(loc, options: nil)
        guard !hits.isEmpty else { return }
        dragging = true
        lastDragPt = loc
        lastDragTS = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        velYaw = 0
        velPitch = 0
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragging, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let dx = Float(loc.x - lastDragPt.x)
        let dy = Float(loc.y - lastDragPt.y)
        let ts = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let dt = Float(max(ts - lastDragTS, 1.0 / 120.0))
        let sens: Float = 0.007
        // On iOS, dragging down means dy > 0, which corresponds to positive pitch. Wait, let's just use the same axis.
        applyDelta(yaw: -dx * sens, pitch: dy * sens)
        let a: Float = 0.4
        velYaw   = velYaw   * (1 - a) + (-dx * sens / dt) * a
        velPitch = velPitch * (1 - a) + ( dy * sens / dt) * a
        lastDragPt = loc
        lastDragTS = ts
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragging = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragging = false
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            frameTimer?.invalidate()
            frameTimer = nil
        }
    }
    #endif
}
