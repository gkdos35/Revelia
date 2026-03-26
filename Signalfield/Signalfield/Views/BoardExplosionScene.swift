// Signalfield/Views/BoardExplosionScene.swift
//
// SpriteKit scene that animates the hazard-hit board destruction.
//
// The scene is sized to match the board canvas exactly and overlays the SwiftUI
// board at the moment of explosion. On creation it recreates each tile as a
// solid-fill SKShapeNode positioned at the tile's exact screen location.
//
// Animation sequence (~1.7 s from first crack to last fragment off-screen):
//   Phase 1 — Impact flash: origin tile pulses bright amber
//   Phase 2 — Chain reaction: tiles shatter outward ring by ring
//   Phase 3 — Collapse: fragments fall with gravity + tumble
//   Phase 4 — Settle: lingering dust, then onComplete callback fires
//
// All timing uses SKAction sequences — no physics bodies — for fully
// deterministic, predictable animation that always finishes on schedule.

import SpriteKit

final class BoardExplosionScene: SKScene {

    // MARK: - Configuration

    private let tileData: [TileExplosionData]
    private let biomeId: Int
    private let gridShape: GridShape
    private let boardCanvasHeight: CGFloat
    private let onSoundEffect: ((ExplosionSoundEvent) -> Void)?
    private let onComplete: () -> Void

    /// Sound hooks the view layer can implement (or ignore).
    enum ExplosionSoundEvent {
        case impact      // 0.0 s — hazard tile flashes
        case crackWave   // each ring of tiles cracking
    }

    // MARK: - Timing Constants

    /// Delay between successive ring waves (seconds).
    /// Guards against didMove(to:) being called more than once.
    /// SKScene.didMove(to:) can be called again if the scene is re-presented
    /// (e.g. by an unexpected SpriteKit/SwiftUI interaction). This flag ensures
    /// runExplosion() only ever fires once per scene instance.
    private var hasStarted = false

    private let ringDelay: TimeInterval = 0.12
    /// How long a tile's crack-apart takes.
    private let crackDuration: TimeInterval = 0.08
    /// How long fragments take to fall off screen after cracking.
    private let fallDuration: TimeInterval = 0.65
    /// Post-animation stillness before calling onComplete.
    private let settlePause: TimeInterval = 0.30
    /// Impact flash duration.
    private let flashDuration: TimeInterval = 0.18

    // MARK: - Init

    /// - Parameters:
    ///   - size: The board canvas size in points (matches `boardCanvasSize` in GameView).
    ///   - tileData: Per-tile snapshot data built by GameView.
    ///   - biomeId: Current biome ID (drives dust particle colours).
    ///   - gridShape: `.square` or `.hexagonal` — controls tile sprite shape and fragment geometry.
    ///   - onSoundEffect: Optional hook called at key moments for SFX.
    ///   - onComplete: Called once the last fragment has left and dust settles.
    init(size: CGSize,
         tileData: [TileExplosionData],
         biomeId: Int,
         gridShape: GridShape = .square,
         onSoundEffect: ((ExplosionSoundEvent) -> Void)? = nil,
         onComplete: @escaping () -> Void) {
        self.tileData = tileData
        self.biomeId = biomeId
        self.gridShape = gridShape
        self.boardCanvasHeight = size.height
        self.onSoundEffect = onSoundEffect
        self.onComplete = onComplete
        super.init(size: size)

        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used") }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        guard !hasStarted else { return }
        hasStarted = true
        runExplosion()
    }

    // MARK: - Main Animation

    private func runExplosion() {
        let maxRing = tileData.map(\.ringDistance).max() ?? 0

        // Compute the SpriteKit-space position of the explosion origin tile.
        // All other tiles push radially away from this point.
        let originData = tileData.first(where: \.isExplosionOrigin)
        let explosionOriginPos: CGPoint = originData.map {
            CGPoint(x: $0.center.x, y: boardCanvasHeight - $0.center.y)
        } ?? CGPoint(x: size.width / 2, y: size.height / 2)

        // -------------------------------------------------------------------
        // Phase 1: Impact flash on the origin tile
        // -------------------------------------------------------------------
        onSoundEffect?(.impact)

        for data in tileData where data.isExplosionOrigin {
            let sprite = makeTileSprite(data)
            addChild(sprite)

            let flash = SKAction.sequence([
                SKAction.run { sprite.fillColor = NSColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0) },
                SKAction.wait(forDuration: flashDuration * 0.4),
                SKAction.run { sprite.fillColor = data.fillColor },
                SKAction.wait(forDuration: flashDuration * 0.6),
            ])
            sprite.run(flash)
        }

        // -------------------------------------------------------------------
        // Phase 2 + 3: Ring-by-ring shatter and collapse
        // -------------------------------------------------------------------
        for data in tileData where !data.isExplosionOrigin {
            let sprite = makeTileSprite(data)
            addChild(sprite)
        }

        // Schedule each ring after its delay.
        for ring in 0...maxRing {
            let delay = flashDuration + TimeInterval(ring) * ringDelay
            let tilesInRing = tileData.filter { $0.ringDistance == ring }

            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in
                    guard let self else { return }
                    if ring > 0 { self.onSoundEffect?(.crackWave) }
                    for data in tilesInRing {
                        self.shatterTile(data: data, maxRing: maxRing,
                                         explosionOriginPos: explosionOriginPos)
                    }
                }
            ]))
        }

        // -------------------------------------------------------------------
        // Phase 4: Settle — dust + completion callback
        // -------------------------------------------------------------------
        let totalAnimTime = flashDuration
            + TimeInterval(maxRing) * ringDelay
            + crackDuration + fallDuration
            + settlePause

        run(SKAction.sequence([
            SKAction.wait(forDuration: totalAnimTime - settlePause),
            SKAction.run { [weak self] in self?.spawnLingeringDust() },
            SKAction.wait(forDuration: settlePause),
            SKAction.run { [weak self] in self?.onComplete() }
        ]))
    }

    // MARK: - Tile Sprite Factory

    /// Create a solid-fill shape node matching the tile's position and colour.
    /// Position is flipped from SwiftUI Y-down to SpriteKit Y-up.
    /// Shape is a rounded rectangle for square grids and a flat-top hexagon for hex grids.
    private func makeTileSprite(_ data: TileExplosionData) -> SKShapeNode {
        let w = data.size.width
        let h = data.size.height

        let path: CGPath
        if gridShape == .hexagonal {
            path = flatTopHexPath(width: w, height: h)
        } else {
            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        }

        let node = SKShapeNode(path: path)
        node.fillColor = data.fillColor
        node.strokeColor = NSColor.black.withAlphaComponent(0.30)
        node.lineWidth = 0.5
        // Flip Y: SpriteKit origin is bottom-left; SwiftUI is top-left.
        node.position = CGPoint(x: data.center.x,
                                y: boardCanvasHeight - data.center.y)
        node.name = "tile_\(data.coord.row)_\(data.coord.col)"
        node.zPosition = 1
        return node
    }

    // MARK: - Hex Path Helper

    /// Flat-top hexagon path centred at origin in SpriteKit space (Y-up).
    /// Matches the vertex formula used by TileBackgroundShape in TileView.swift:
    ///   circumradius R = min(w/2, h/√3),  half-height h_half = R × (√3/2)
    private func flatTopHexPath(width w: CGFloat, height h: CGFloat) -> CGPath {
        let R: CGFloat = min(w / 2.0, h / 1.7320508)
        let hh: CGFloat = R * 0.8660254   // R × (√3/2)

        // Vertices in clockwise order (SpriteKit Y-up, flat-top orientation):
        //   right, upper-right, upper-left, left, lower-left, lower-right
        let verts: [CGPoint] = [
            CGPoint(x:  R,       y:  0),
            CGPoint(x:  R * 0.5, y:  hh),
            CGPoint(x: -R * 0.5, y:  hh),
            CGPoint(x: -R,       y:  0),
            CGPoint(x: -R * 0.5, y: -hh),
            CGPoint(x:  R * 0.5, y: -hh),
        ]

        let path = CGMutablePath()
        path.move(to: verts[0])
        for v in verts.dropFirst() { path.addLine(to: v) }
        path.closeSubpath()
        return path
    }

    // MARK: - Shatter a Single Tile

    /// Replace a tile sprite with 2–5 irregular polygon fragments that crack apart
    /// and fall with simulated gravity.
    ///
    /// - Parameter explosionOriginPos: SpriteKit-space position of the hazard tile.
    ///   Fragments push radially away from this point.
    private func shatterTile(data: TileExplosionData, maxRing: Int,
                              explosionOriginPos: CGPoint) {
        // Find and remove the solid tile sprite.
        let tileName = "tile_\(data.coord.row)_\(data.coord.col)"
        guard let tileNode = childNode(withName: tileName) as? SKShapeNode else { return }
        let tilePos = tileNode.position
        tileNode.removeFromParent()

        // Fragment count: more near origin, fewer at edges.
        let fragmentCount: Int
        if data.ringDistance == 0 {
            fragmentCount = Int.random(in: 4...5)
        } else if data.ringDistance <= maxRing / 3 + 1 {
            fragmentCount = Int.random(in: 3...4)
        } else {
            fragmentCount = Int.random(in: 2...3)
        }

        // Generate fragment polygons using radial slicing.
        // Hex tiles slice a hexagonal boundary; square tiles slice a rectangle.
        let w = data.size.width
        let h = data.size.height
        let fragments: [CGPath]
        if gridShape == .hexagonal {
            fragments = hexRadialSliceFragments(width: w, height: h, count: fragmentCount)
        } else {
            fragments = radialSliceFragments(width: w, height: h, count: fragmentCount)
        }

        // Dust burst at tile centre.
        spawnDustBurst(at: tilePos, count: Int.random(in: 4...8))

        // -------------------------------------------------------------------
        // Compute the radial push direction from explosion origin to this tile.
        // Origin tile (ringDistance == 0) gets a full random push since it's
        // the epicentre and explodes in all directions simultaneously.
        // -------------------------------------------------------------------
        let dx = tilePos.x - explosionOriginPos.x
        let dy = tilePos.y - explosionOriginPos.y
        let dist = sqrt(dx * dx + dy * dy)

        // Directional angle: away from the explosion origin.
        // For the origin tile itself (dist ≈ 0), use a random angle.
        let radialAngle: CGFloat = dist > 1.0
            ? atan2(dy, dx)
            : CGFloat.random(in: 0 ... (.pi * 2))

        // Push strength: strongest at origin, tapers off with ring distance.
        // Ring 0 = 22pt, ring 1 ≈ 18pt, ring 4 ≈ 8pt, beyond = minimum 5pt.
        let pushStrength: CGFloat = max(5.0, 22.0 - CGFloat(data.ringDistance) * 3.5)

        let pushX = cos(radialAngle) * pushStrength
        let pushY = sin(radialAngle) * pushStrength

        // Crack apart: small initial offset along the radial direction.
        let crackX = cos(radialAngle) * CGFloat.random(in: 2...5)
        let crackY = sin(radialAngle) * CGFloat.random(in: 2...5)

        // Create and animate each fragment.
        for (_, path) in fragments.enumerated() {
            let frag = SKShapeNode(path: path)
            frag.fillColor = data.fillColor
            frag.strokeColor = NSColor.black.withAlphaComponent(0.25)
            frag.lineWidth = 0.5
            frag.position = tilePos
            frag.zPosition = 2
            addChild(frag)

            // Fall parameters.
            // hDrift: radial push component + small random scatter for organic feel.
            // vFall: gravity pull downward, partially offset by radial Y component.
            let scatter = CGFloat.random(in: -20...20)
            let hDrift = pushX + scatter
            let vFall: CGFloat = -(350 + CGFloat.random(in: 0...200)) + pushY
            let rotation = CGFloat.random(in: -2.0...2.0)

            let crack = SKAction.moveBy(x: crackX, y: crackY, duration: crackDuration)
            crack.timingMode = .easeOut

            let fall = SKAction.group([
                SKAction.moveBy(x: hDrift, y: vFall, duration: fallDuration),
                SKAction.rotate(byAngle: rotation, duration: fallDuration),
                SKAction.fadeAlpha(to: 0.35, duration: fallDuration)
            ])
            // Ease-in simulates gravity acceleration.
            fall.timingMode = .easeIn

            frag.run(SKAction.sequence([
                crack,
                SKAction.wait(forDuration: 0.05),
                fall,
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Radial Slice Fragment Generation

    /// Slice a rectangle into `count` irregular polygon fragments using radial cuts
    /// from a jittered centre point.
    ///
    /// Returns an array of `CGPath` objects, each a closed polygon defined in the
    /// tile's local coordinate system (centred at origin, spanning -w/2...+w/2).
    private func radialSliceFragments(width w: CGFloat, height h: CGFloat,
                                      count: Int) -> [CGPath] {
        // Jittered centre (the "hub" of all cuts).
        let cx = CGFloat.random(in: -w * 0.15 ... w * 0.15)
        let cy = CGFloat.random(in: -h * 0.15 ... h * 0.15)
        let center = CGPoint(x: cx, y: cy)

        // Generate sorted random angles for the cuts.
        var angles: [CGFloat] = (0..<count).map { _ in CGFloat.random(in: 0 ... .pi * 2) }
        angles.sort()

        let halfW = w / 2
        let halfH = h / 2
        let rect = CGRect(x: -halfW, y: -halfH, width: w, height: h)

        var paths: [CGPath] = []

        for i in 0..<count {
            let a1 = angles[i]
            let a2 = angles[(i + 1) % count]

            let path = CGMutablePath()
            path.move(to: center)

            // Edge intersection for angle a1.
            let e1 = edgeIntersection(from: center, angle: a1, rect: rect)
            path.addLine(to: e1)

            // Walk around the rectangle perimeter from e1 to e2 (clockwise).
            let e2 = edgeIntersection(from: center, angle: a2, rect: rect)
            addPerimeterWalk(to: path, from: e1, to: e2, rect: rect)

            path.addLine(to: e2)
            path.closeSubpath()
            paths.append(path)
        }

        return paths
    }

    /// Compute where a ray from `origin` at `angle` exits `rect`.
    private func edgeIntersection(from origin: CGPoint, angle: CGFloat,
                                  rect: CGRect) -> CGPoint {
        let dx = cos(angle)
        let dy = sin(angle)

        // Check intersection with each edge; take the closest positive t.
        var bestT: CGFloat = .greatestFiniteMagnitude

        // Right edge (x = maxX).
        if dx > 1e-9 {
            let t = (rect.maxX - origin.x) / dx
            if t > 0 { bestT = min(bestT, t) }
        }
        // Left edge (x = minX).
        if dx < -1e-9 {
            let t = (rect.minX - origin.x) / dx
            if t > 0 { bestT = min(bestT, t) }
        }
        // Top edge (y = maxY).
        if dy > 1e-9 {
            let t = (rect.maxY - origin.y) / dy
            if t > 0 { bestT = min(bestT, t) }
        }
        // Bottom edge (y = minY).
        if dy < -1e-9 {
            let t = (rect.minY - origin.y) / dy
            if t > 0 { bestT = min(bestT, t) }
        }

        return CGPoint(x: origin.x + dx * bestT,
                       y: origin.y + dy * bestT)
    }

    /// Walk the rectangle perimeter clockwise from `start` to `end`, adding
    /// all intermediate corner vertices to `path`.
    private func addPerimeterWalk(to path: CGMutablePath,
                                  from start: CGPoint, to end: CGPoint,
                                  rect: CGRect) {
        // Rectangle corners in clockwise order (SpriteKit Y-up):
        //   topRight → bottomRight → bottomLeft → topLeft
        let corners: [CGPoint] = [
            CGPoint(x: rect.maxX, y: rect.maxY),  // top-right
            CGPoint(x: rect.maxX, y: rect.minY),  // bottom-right
            CGPoint(x: rect.minX, y: rect.minY),  // bottom-left
            CGPoint(x: rect.minX, y: rect.maxY),  // top-left
        ]

        // Map a point on the perimeter to a scalar parameter [0, 4) going clockwise.
        func perimParam(_ p: CGPoint) -> CGFloat {
            // Top edge (right→left? No — we go clockwise, which is:
            //   right edge down, bottom edge left, left edge up, top edge right.
            // Edge 0: right edge (maxX), from maxY to minY
            if abs(p.x - rect.maxX) < 0.5 {
                return 0 + (rect.maxY - p.y) / max(1, rect.height)
            }
            // Edge 1: bottom edge (minY), from maxX to minX
            if abs(p.y - rect.minY) < 0.5 {
                return 1 + (rect.maxX - p.x) / max(1, rect.width)
            }
            // Edge 2: left edge (minX), from minY to maxY
            if abs(p.x - rect.minX) < 0.5 {
                return 2 + (p.y - rect.minY) / max(1, rect.height)
            }
            // Edge 3: top edge (maxY), from minX to maxX
            return 3 + (p.x - rect.minX) / max(1, rect.width)
        }

        let t0 = perimParam(start)
        let t1 = perimParam(end)

        // Walk from t0 to t1, wrapping around if needed (always clockwise = increasing t).
        // Emit any corner whose parameter falls strictly between t0 and t1 (mod 4).
        for ci in 0..<4 {
            let ct = CGFloat(ci) + 0.0001  // Slightly past the corner
            let adjusted = (ct - t0).truncatingRemainder(dividingBy: 4)
            let range = ((t1 - t0).truncatingRemainder(dividingBy: 4) + 4)
                .truncatingRemainder(dividingBy: 4)
            let adjustedPos = (adjusted + 4).truncatingRemainder(dividingBy: 4)
            if adjustedPos > 0.001 && adjustedPos < range - 0.001 {
                path.addLine(to: corners[ci])
            }
        }
    }

    // MARK: - Hex Radial Slice Fragment Generation

    /// Slice a flat-top hexagon into `count` irregular polygon fragments using radial
    /// cuts from a jittered centre point. Mirrors `radialSliceFragments` but uses the
    /// hexagon boundary instead of a rectangle for both ray-exit and perimeter walking.
    ///
    /// Returns `CGPath` objects in the tile's local coordinate system (centred at origin).
    private func hexRadialSliceFragments(width w: CGFloat, height h: CGFloat,
                                         count: Int) -> [CGPath] {
        // Hex geometry — same formula as flatTopHexPath.
        let R: CGFloat = min(w / 2.0, h / 1.7320508)
        let hh: CGFloat = R * 0.8660254

        // The 6 vertices of the flat-top hex in clockwise order (SpriteKit Y-up).
        let hexVerts: [CGPoint] = [
            CGPoint(x:  R,       y:  0),
            CGPoint(x:  R * 0.5, y:  hh),
            CGPoint(x: -R * 0.5, y:  hh),
            CGPoint(x: -R,       y:  0),
            CGPoint(x: -R * 0.5, y: -hh),
            CGPoint(x:  R * 0.5, y: -hh),
        ]
        let edgeCount = hexVerts.count   // 6

        // Jittered hub centre.
        let cx = CGFloat.random(in: -R * 0.15 ... R * 0.15)
        let cy = CGFloat.random(in: -hh * 0.15 ... hh * 0.15)
        let hub = CGPoint(x: cx, y: cy)

        // Sorted random cut angles.
        var angles: [CGFloat] = (0..<count).map { _ in CGFloat.random(in: 0 ... .pi * 2) }
        angles.sort()

        // --- Helpers ---

        /// Find where a ray from `origin` at `angle` first exits the hexagon.
        /// Tests each of the 6 edges; returns the closest positive intersection.
        func hexEdgeIntersection(from origin: CGPoint, angle: CGFloat) -> CGPoint {
            let dx = cos(angle)
            let dy = sin(angle)
            var bestT: CGFloat = .greatestFiniteMagnitude

            for i in 0..<edgeCount {
                let a = hexVerts[i]
                let b = hexVerts[(i + 1) % edgeCount]
                // Parametric edge: P = a + s*(b-a), s ∈ [0,1]
                // Ray: Q = origin + t*(dx,dy), t > 0
                // Solve: origin + t*(dx,dy) = a + s*(b-a)
                let ex = b.x - a.x
                let ey = b.y - a.y
                let denom = dx * ey - dy * ex
                guard abs(denom) > 1e-9 else { continue }
                let t = ((a.x - origin.x) * ey - (a.y - origin.y) * ex) / denom
                let s = ((a.x - origin.x) * dy - (a.y - origin.y) * dx) / denom
                guard t > 1e-9 && s >= -1e-6 && s <= 1.0 + 1e-6 else { continue }
                if t < bestT { bestT = t }
            }

            guard bestT < .greatestFiniteMagnitude else {
                return origin  // fallback: shouldn't happen for a hub inside the hex
            }
            return CGPoint(x: origin.x + dx * bestT, y: origin.y + dy * bestT)
        }

        /// Map a point on the hex perimeter to a scalar parameter [0, 6) going clockwise.
        func hexPerimParam(_ p: CGPoint) -> CGFloat {
            for i in 0..<edgeCount {
                let a = hexVerts[i]
                let b = hexVerts[(i + 1) % edgeCount]
                let ex = b.x - a.x
                let ey = b.y - a.y
                let len = sqrt(ex * ex + ey * ey)
                guard len > 1e-9 else { continue }
                // Project p onto this edge.
                let px = p.x - a.x
                let py = p.y - a.y
                let t = (px * ex + py * ey) / (len * len)
                // Perpendicular distance to the edge line.
                let dist = abs(px * ey - py * ex) / len
                if dist < 0.6 && t >= -0.01 && t <= 1.01 {
                    return CGFloat(i) + max(0, min(1, t))
                }
            }
            return 0  // fallback
        }

        /// Walk the hex perimeter clockwise from `start` to `end`, inserting any
        /// hex vertices that fall strictly between them.
        func addHexPerimeterWalk(to path: CGMutablePath,
                                 from start: CGPoint, to end: CGPoint) {
            let t0 = hexPerimParam(start)
            let t1 = hexPerimParam(end)

            for ci in 0..<edgeCount {
                let ct = CGFloat(ci) + 0.0001   // Slightly past the vertex
                let range = ((t1 - t0).truncatingRemainder(dividingBy: CGFloat(edgeCount))
                    + CGFloat(edgeCount)).truncatingRemainder(dividingBy: CGFloat(edgeCount))
                let adjusted = ((ct - t0).truncatingRemainder(dividingBy: CGFloat(edgeCount))
                    + CGFloat(edgeCount)).truncatingRemainder(dividingBy: CGFloat(edgeCount))
                if adjusted > 0.001 && adjusted < range - 0.001 {
                    path.addLine(to: hexVerts[ci])
                }
            }
        }

        // --- Build fragment paths ---
        var paths: [CGPath] = []

        for i in 0..<count {
            let a1 = angles[i]
            let a2 = angles[(i + 1) % count]

            let path = CGMutablePath()
            path.move(to: hub)

            let e1 = hexEdgeIntersection(from: hub, angle: a1)
            path.addLine(to: e1)

            let e2 = hexEdgeIntersection(from: hub, angle: a2)
            addHexPerimeterWalk(to: path, from: e1, to: e2)

            path.addLine(to: e2)
            path.closeSubpath()
            paths.append(path)
        }

        return paths
    }

    // MARK: - Dust Particles

    /// Burst of small biome-coloured particles when a tile cracks.
    private func spawnDustBurst(at position: CGPoint, count: Int) {
        let colors = Self.dustColors(biomeId: biomeId)
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...3.0))
            dot.fillColor = colors.randomElement() ?? .white
            dot.strokeColor = .clear
            dot.position = position
            dot.zPosition = 10
            dot.alpha = CGFloat.random(in: 0.6...1.0)
            addChild(dot)

            let vx = CGFloat.random(in: -60...60)
            let vy = CGFloat.random(in: -20...80)  // Bias upward for a "puff" feel
            let lifetime = TimeInterval.random(in: 0.2...0.45)

            dot.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: vx * CGFloat(lifetime),
                                    y: vy * CGFloat(lifetime),
                                    duration: lifetime),
                    SKAction.fadeOut(withDuration: lifetime),
                    SKAction.scale(to: 0.3, duration: lifetime),
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Lingering dust particles that float after the board is gone.
    private func spawnLingeringDust() {
        let colors = Self.dustColors(biomeId: biomeId)
        let centerX = size.width / 2
        let centerY = size.height / 2

        for _ in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.5))
            dot.fillColor = colors.randomElement() ?? .white
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: centerX + CGFloat.random(in: -size.width * 0.3 ... size.width * 0.3),
                y: centerY + CGFloat.random(in: -size.height * 0.2 ... size.height * 0.2)
            )
            dot.zPosition = 10
            dot.alpha = CGFloat.random(in: 0.3...0.6)
            addChild(dot)

            let lifetime: TimeInterval = .random(in: 0.4...0.8)
            dot.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -15...15),
                                    y: CGFloat.random(in: 10...30),
                                    duration: lifetime),
                    SKAction.fadeOut(withDuration: lifetime),
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Dust Colour Palettes

    /// Biome-specific dust/particle colours for the explosion.
    /// Matches the aesthetic of each environment.
    static func dustColors(biomeId: Int) -> [NSColor] {
        switch biomeId % 9 {
        case 0:  // Training Range — green leaf / petal
            return [NSColor(red: 0.55, green: 0.80, blue: 0.28, alpha: 1),
                    NSColor(red: 0.76, green: 0.88, blue: 0.56, alpha: 1),
                    NSColor(red: 0.80, green: 0.92, blue: 0.55, alpha: 1)]
        case 1:  // Fog Marsh — seafoam / watery blue
            return [NSColor(red: 0.50, green: 0.83, blue: 0.71, alpha: 1),
                    NSColor.white.withAlphaComponent(0.70),
                    NSColor(red: 0.38, green: 0.68, blue: 0.64, alpha: 1)]
        case 2:  // Bioluminescence — electric cyan sparks
            return [NSColor(red: 0.44, green: 0.88, blue: 0.88, alpha: 1),
                    NSColor.white.withAlphaComponent(0.80),
                    NSColor(red: 0.28, green: 0.92, blue: 0.96, alpha: 1)]
        case 3:  // Frozen Mirrors — white snow / pale ice
            return [NSColor.white.withAlphaComponent(0.90),
                    NSColor.white.withAlphaComponent(0.60),
                    NSColor(red: 0.72, green: 0.88, blue: 0.98, alpha: 1)]
        case 4:  // Ruins — warm gold dust / sandy stone
            return [NSColor(red: 0.88, green: 0.72, blue: 0.40, alpha: 1),
                    NSColor(red: 0.78, green: 0.62, blue: 0.32, alpha: 1),
                    NSColor(red: 0.91, green: 0.78, blue: 0.50, alpha: 1)]
        case 5:  // The Underside — purple mineral sparks
            return [NSColor(red: 0.58, green: 0.38, blue: 0.88, alpha: 1),
                    NSColor(red: 0.75, green: 0.63, blue: 0.88, alpha: 1),
                    NSColor.white.withAlphaComponent(0.55)]
        case 6:  // Coral Basin — bubble pinks / tropical teal
            return [NSColor(red: 0.94, green: 0.66, blue: 0.63, alpha: 1),
                    NSColor.white.withAlphaComponent(0.65),
                    NSColor(red: 0.28, green: 0.74, blue: 0.72, alpha: 1)]
        case 7:  // Quicksand — amber sand grains / dust
            return [NSColor(red: 0.84, green: 0.64, blue: 0.22, alpha: 1),
                    NSColor(red: 0.72, green: 0.54, blue: 0.28, alpha: 1),
                    NSColor(red: 0.91, green: 0.75, blue: 0.35, alpha: 1)]
        default: // The Delta — mixed specks from multiple biomes
            return [NSColor(red: 0.55, green: 0.80, blue: 0.28, alpha: 1),
                    NSColor(red: 0.28, green: 0.74, blue: 0.72, alpha: 1),
                    NSColor(red: 0.88, green: 0.72, blue: 0.40, alpha: 1),
                    NSColor(red: 0.82, green: 0.78, blue: 0.69, alpha: 1)]
        }
    }
}
