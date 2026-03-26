// Signalfield/Views/BoardInputView.swift

import SwiftUI
import AppKit

// MARK: - Input Actions

/// The three player input actions, resolved from mouse events.
enum BoardInputAction {
    case scan(Coordinate)      // Left-click on a tile
    case tag(Coordinate)       // Right-click or ctrl-click on a tile
    case chord(Coordinate)     // Shift-click on a tile
}

// MARK: - NSViewRepresentable Wrapper

/// An invisible overlay that captures mouse events on the board grid
/// and translates them into game actions.
///
/// This replaces SwiftUI's gesture system for reliable:
/// - Right-click → tag (no context menu popup)
/// - Ctrl-click → tag (macOS treats ctrl-click as right-click)
/// - Shift-click → chord
/// - Plain left-click → scan
///
/// Coordinate conversion is geometry-aware:
/// - Square grids use simple division by `(tileSize + gridSpacing)`.
/// - Hex grids delegate to `HexagonalGridGeometry.coordinate(at:)`, which
///   performs proximity-based hit testing across adjacent hex cells.
struct BoardInputView: NSViewRepresentable {
    let boardWidth: Int
    let boardHeight: Int
    let tileSize: CGFloat
    let gridSpacing: CGFloat
    /// The board topology — controls how mouse positions are mapped to coordinates.
    var gridShape: GridShape = .square
    let onAction: (BoardInputAction) -> Void
    /// Called with the coordinate under the cursor, or nil when the cursor leaves the board.
    var onHover: ((Coordinate?) -> Void)? = nil

    func makeNSView(context: Context) -> BoardInputNSView {
        let view = BoardInputNSView()
        view.boardWidth = boardWidth
        view.boardHeight = boardHeight
        view.tileSize = tileSize
        view.gridSpacing = gridSpacing
        view.gridShape = gridShape
        view.onAction = onAction
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: BoardInputNSView, context: Context) {
        nsView.boardWidth = boardWidth
        nsView.boardHeight = boardHeight
        nsView.tileSize = tileSize
        nsView.gridSpacing = gridSpacing
        nsView.gridShape = gridShape
        nsView.onAction = onAction
        nsView.onHover = onHover
    }
}

// MARK: - The Actual NSView

/// Custom NSView that handles mouse events for the game board.
class BoardInputNSView: NSView {
    var boardWidth: Int = 0
    var boardHeight: Int = 0
    var tileSize: CGFloat = 0
    var gridSpacing: CGFloat = 0
    /// The board topology — controls how mouse positions are mapped to tile coordinates.
    var gridShape: GridShape = .square
    var onAction: ((BoardInputAction) -> Void)?
    /// Called with the hovered board coordinate, or nil when cursor leaves.
    var onHover: ((Coordinate?) -> Void)?

    // MARK: - Setup

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept clicks even when the window isn't focused
        true
    }

    /// Rebuild the tracking area whenever the view is resized.
    /// The tracking area covers the full view bounds and fires mouseMoved
    /// and mouseExited events so we can compute which tile is under the cursor.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    // MARK: - Coordinate Conversion

    /// Convert a mouse location (in NSView coordinates, origin bottom-left)
    /// to a board coordinate (row 0 = top).
    ///
    /// NSView has origin at bottom-left with y increasing upward.
    /// The board canvas has origin at top-left with y increasing downward.
    /// We flip the y-axis first, then delegate to the appropriate geometry.
    private func boardCoordinate(from event: NSEvent) -> Coordinate? {
        let location = convert(event.locationInWindow, from: nil)

        // Flip y to convert NSView space (y-up) → canvas space (y-down, origin top-left)
        let canvasPoint = CGPoint(x: location.x, y: bounds.height - location.y)

        switch gridShape {
        case .square:
            // Square grid: straightforward division into (tileSize + spacing) cells.
            return SquareGridGeometry().coordinate(
                at: canvasPoint,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                tileSize: tileSize,
                spacing: gridSpacing
            )
        case .hexagonal:
            // Hex grid: proximity-based hit testing via HexagonalGridGeometry.
            // Returns the hex tile whose center is closest to the click point.
            return HexagonalGridGeometry().coordinate(
                at: canvasPoint,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                tileSize: tileSize,
                spacing: gridSpacing
            )
        }
    }

    // MARK: - Hit Testing

    /// AppKit calls hitTest(_:) BEFORE delivering any mouse event to determine which
    /// NSView should receive it. By returning nil for clicks outside valid board tiles,
    /// we ensure that AppKit skips this view entirely and continues its own hit-testing —
    /// finding the correct SwiftUI-backed NSView for HUD buttons, settings gear, etc.
    ///
    /// Calling super.mouseDown(with:) from within mouseDown is NOT equivalent: by the
    /// time mouseDown is called, AppKit has already "committed" the event to this view.
    /// super.mouseDown only walks the responder chain upward from this view, which never
    /// reaches SwiftUI buttons (they live in a separate NSView branch). Overriding
    /// hitTest is the only correct way to pass the event back to AppKit for re-routing.
    override func hitTest(_ point: NSPoint) -> NSView? {
        // point is in superview coordinate space. Convert to our local coordinate space.
        let localPoint = convert(point, from: superview)

        // Flip y-axis: NSView origin is bottom-left (y increases up),
        // but the board canvas uses top-left origin (y increases down).
        let canvasPoint = CGPoint(x: localPoint.x, y: bounds.height - localPoint.y)

        // Only claim the hit if the click lands on a valid board tile.
        // Clicks in spacing gaps, padding, or anywhere outside the board are
        // returned as nil — AppKit then hits the next view in the hierarchy.
        switch gridShape {
        case .square:
            guard SquareGridGeometry().coordinate(
                at: canvasPoint,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                tileSize: tileSize,
                spacing: gridSpacing) != nil
            else { return nil }
        case .hexagonal:
            guard HexagonalGridGeometry().coordinate(
                at: canvasPoint,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                tileSize: tileSize,
                spacing: gridSpacing) != nil
            else { return nil }
        }
        return self
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Ignore the second (and subsequent) clicks of a double/triple-click.
        // Only the first mouseDown (clickCount == 1) should trigger a game action.
        // hitTest(_:) already guarantees this view only receives clicks on valid tiles,
        // so boardCoordinate should return non-nil here — the guard is a safety net.
        guard event.clickCount == 1 else { return }
        guard let coord = boardCoordinate(from: event) else { return }

        if event.modifierFlags.contains(.shift) {
            onAction?(.chord(coord))
        } else if event.modifierFlags.contains(.control) {
            onAction?(.tag(coord))
        } else {
            onAction?(.scan(coord))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // hitTest(_:) already guarantees the click is on a valid tile.
        guard let coord = boardCoordinate(from: event) else { return }
        onAction?(.tag(coord))
    }

    override func mouseMoved(with event: NSEvent) {
        onHover?(boardCoordinate(from: event))
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(nil)
    }

    // Override to prevent the default context menu from appearing
    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }
}
