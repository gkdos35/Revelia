// Revelia/Views/BoardExplosionView.swift
//
// SwiftUI wrapper for the SpriteKit hazard-hit explosion scene.
//
// Architecture: the SKView is ALWAYS mounted in the view tree (never conditionally
// inserted via `if`). This is critical because creating an NSView and inserting it
// into the macOS window hierarchy takes ~1 second. By keeping the SKView pre-mounted,
// we pay that cost once at game load. When the explosion triggers, we just present a
// scene on the already-mounted view — didMove(to:) fires within one frame (~16 ms).
//
// The explosion scene is presented via updateNSView when `scene` transitions from
// nil to non-nil. Once presented, the scene is never replaced — hasStarted in the
// scene guards against accidental re-runs, and updateNSView skips presentScene if
// the view already has the same scene.
//
// Usage (in GameView — always in the ZStack, NOT conditional):
//     BoardExplosionView(scene: explosionScene)
//         .frame(width: boardCanvasSize.width, height: boardCanvasSize.height)
//         .allowsHitTesting(false)

import SwiftUI
import SpriteKit

/// NSViewRepresentable that wraps a pre-mounted SKView. The SKView exists from game
/// start. A scene is presented only when `scene` goes from nil to non-nil, at which
/// point `didMove(to:)` fires on the next frame and the explosion animation begins.
struct BoardExplosionView: NSViewRepresentable {

    /// The explosion scene to present. nil = no explosion (SKView shows nothing).
    /// Set to a configured BoardExplosionScene when the hazard is hit.
    var scene: BoardExplosionScene?

    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        // Present a minimal transparent scene so the SKView doesn't render
        // its default opaque grey background while waiting for the explosion.
        let placeholder = SKScene(size: CGSize(width: 1, height: 1))
        placeholder.backgroundColor = .clear
        placeholder.scaleMode = .resizeFill
        view.presentScene(placeholder)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        // Present the scene exactly once: when `scene` transitions from nil to
        // a real BoardExplosionScene. After that, the scene manages its own
        // lifecycle and we never touch the SKView again.
        if let scene = scene, nsView.scene !== scene {
            nsView.presentScene(scene)
        }
    }
}
