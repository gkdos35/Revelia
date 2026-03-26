// Signalfield/Tutorial/TutorialTooltipView.swift
//
// Reusable parchment-style tooltip used by:
//   1. The L1 guided tutorial (each step's instructional callout)
//   2. Biome intro tooltips (non-blocking, first level of each biome)
//
// Visual style:
//   - Parchment-toned background (#F5E6C8 / warm cream)
//   - Thin dark-brown border at 50% opacity
//   - Drop shadow
//   - Directional arrow notch pointing at the target
//   - Warm dark-brown text
//   - Max width 260pt, text wraps within

import Combine
import SwiftUI

// MARK: - Arrow Edge

/// Which edge of the tooltip the directional notch appears on.
/// The notch points FROM this edge TOWARD the target element.
enum TooltipArrowEdge {
    case top, bottom, leading, trailing
    case none   // No arrow (centered tooltips with no specific target)
}

// MARK: - TutorialTooltipView

/// A parchment-styled callout tooltip with an optional directional arrow.
///
/// - Parameters:
///   - message: The instruction text to display.
///   - buttonLabel: Label for the primary action button. Empty string = no button.
///   - arrowEdge: Which edge shows the directional arrow notch.
///   - onAction: Called when the primary button is tapped (or the tooltip is tapped,
///     for auto-dismiss style tooltips).
struct TutorialTooltipView: View {
    let message: String
    let buttonLabel: String
    let arrowEdge: TooltipArrowEdge
    let onAction: () -> Void

    // Parchment design tokens
    private let parchmentFill   = Color(red: 0xF5/255.0, green: 0xE6/255.0, blue: 0xC8/255.0)
    private let borderColor     = Color(red: 0x6B/255.0, green: 0x5B/255.0, blue: 0x3E/255.0)
    private let textColor       = Color(red: 0x4A/255.0, green: 0x3A/255.0, blue: 0x28/255.0)
    private let buttonFillColor = Color(red: 0x6B/255.0, green: 0x5B/255.0, blue: 0x3E/255.0)

    private let arrowSize: CGFloat = 10
    private let cornerRadius: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            // Top arrow
            if arrowEdge == .top {
                arrowShape(pointing: .up)
            }

            HStack(spacing: 0) {
                // Leading arrow
                if arrowEdge == .leading {
                    arrowShape(pointing: .left)
                }

                // Card body
                VStack(alignment: .leading, spacing: 10) {
                    Text(message)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !buttonLabel.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: onAction) {
                                Text(buttonLabel)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(buttonFillColor)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 260)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(parchmentFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(borderColor.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                // Trailing arrow
                if arrowEdge == .trailing {
                    arrowShape(pointing: .right)
                }
            }

            // Bottom arrow
            if arrowEdge == .bottom {
                arrowShape(pointing: .down)
            }
        }
        .transition(
            .asymmetric(
                insertion:  .opacity.combined(with: .scale(scale: 0.92, anchor: arrowAnchor)),
                removal:    .opacity
            )
        )
    }

    // MARK: - Arrow Shape

    fileprivate enum ArrowDirection { case up, down, left, right }

    @ViewBuilder
    private func arrowShape(pointing direction: ArrowDirection) -> some View {
        let borderColor = borderColor.opacity(0.5)

        ZStack {
            // Border triangle (slightly larger, behind fill)
            ArrowTriangle(direction: direction)
                .fill(borderColor)
                .frame(width:  direction == .left || direction == .right ? arrowSize + 1 : arrowSize + 1,
                       height: direction == .up   || direction == .down  ? arrowSize + 1 : arrowSize + 1)

            // Fill triangle
            ArrowTriangle(direction: direction)
                .fill(parchmentFill)
                .frame(width:  direction == .left || direction == .right ? arrowSize : arrowSize,
                       height: direction == .up   || direction == .down  ? arrowSize : arrowSize)
        }
    }

    private var arrowAnchor: UnitPoint {
        switch arrowEdge {
        case .top:      return .top
        case .bottom:   return .bottom
        case .leading:  return .leading
        case .trailing: return .trailing
        case .none:     return .center
        }
    }
}

// MARK: - Arrow Triangle Shape

private struct ArrowTriangle: Shape {
    let direction: TutorialTooltipView.ArrowDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to:    CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to:    CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .left:
            path.move(to:    CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to:    CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Biome Intro Tooltip

/// Non-blocking floating tooltip for biome introductions.
/// Appears centered horizontally, near the top of the board area.
/// No spotlight — player can interact with the board immediately.
///
/// Two dismiss options:
///   - "Got it" — dismisses for this session only; tooltip reappears next visit
///   - "Don't show again" — dismisses permanently (persisted in SettingsStore)
///
/// Auto-dismisses after 10 seconds (same as "Got it" — session only).
struct BiomeIntroTooltipView: View {
    let biomeId: Int       // Base biome ID (0–8 only; hex biomes pass biomeId % 9)
    let isHex: Bool
    /// Called when the player taps "Got it" or auto-dismiss fires.
    /// Dismisses for this session only — tooltip reappears next time.
    let onDismiss: () -> Void
    /// Called when the player taps "Don't show again".
    /// Should dismiss AND persist to SettingsStore so it never reappears.
    var onDismissPermanently: (() -> Void)? = nil

    @State private var timeRemaining: Double = 10.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // Design tokens (matching TutorialTooltipView parchment style)
    private let parchmentFill   = Color(red: 0xF5/255.0, green: 0xE6/255.0, blue: 0xC8/255.0)
    private let borderColor     = Color(red: 0x6B/255.0, green: 0x5B/255.0, blue: 0x3E/255.0)
    private let textColor       = Color(red: 0x4A/255.0, green: 0x3A/255.0, blue: 0x28/255.0)
    private let buttonFillColor = Color(red: 0x6B/255.0, green: 0x5B/255.0, blue: 0x3E/255.0)
    private let cornerRadius: CGFloat = 10

    private var biomeSuffix: String { isHex ? " (Hex Mode)" : "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(introMessage)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons row: "Got it" primary + "Don't show again" secondary
            HStack {
                Spacer()

                VStack(spacing: 6) {
                    Button(action: onDismiss) {
                        Text("Got it")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(buttonFillColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if let permanentDismiss = onDismissPermanently {
                        Button(action: permanentDismiss) {
                            Text("Don't show again")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(textColor.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(parchmentFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        .transition(
            .asymmetric(
                insertion:  .opacity.combined(with: .scale(scale: 0.92, anchor: .center)),
                removal:    .opacity
            )
        )
        .onReceive(timer) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 { onDismiss() }
        }
    }

    // MARK: - Intro Content per Biome

    private var introMessage: String {
        switch biomeId {
        case 1: return "New: Fogged tiles\(biomeSuffix)! They show a range instead of an exact number. Use your beacon charges to clear the fog."
        case 2: return "New: Pulse charge\(biomeSuffix)! Click the pulse button, then click a tile to briefly light up a 3×3 area. You only get one — use it wisely."
        case 3: return "New: Linked tiles\(biomeSuffix)! Paired tiles show each other's number, not their own. Look for the dot in the corner."
        case 4: return "New: Locked tiles\(biomeSuffix)! They won't open until enough neighbors are revealed. Plan your path to unlock them."
        case 5: return "New: Numbers are flipped\(biomeSuffix)! They now count safe neighbors, not hazards. High numbers mean safety."
        case 6: return "New: Sonar tiles\(biomeSuffix)! They count hazards in four directions — north, south, east, west. Use them to narrow down hazard locations."
        case 7: return "New: Fading signals\(biomeSuffix)! Numbers disappear over time. Scan any hidden tile to bring them back briefly."
        case 8: return "The final chapter\(biomeSuffix). Multiple mechanics are combined in each level. Use everything you've learned!"
        default: return ""
        }
    }
}

// MARK: - Preview

#Preview("Tutorial Tooltip — Got it") {
    VStack(spacing: 24) {
        TutorialTooltipView(
            message:     "This 1 means exactly one of the highlighted tiles hides a hazard.",
            buttonLabel: "Got it",
            arrowEdge:   .bottom,
            onAction:    {}
        )

        TutorialTooltipView(
            message:     "Right-click to tag it as a hazard.",
            buttonLabel: "",
            arrowEdge:   .top,
            onAction:    {}
        )

        BiomeIntroTooltipView(biomeId: 1, isHex: false, onDismiss: {}, onDismissPermanently: {})
    }
    .padding(40)
    .background(Color.gray.opacity(0.2))
}
