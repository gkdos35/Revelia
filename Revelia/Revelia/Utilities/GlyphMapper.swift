// Revelia/Utilities/GlyphMapper.swift
//
// Renders a tile's signal value as pip glyphs (●) instead of Arabic numerals.
// Used by TileView when settingsStore.signalDisplayMode == .glyphs.
//
// Layout rules:
//   1–3:  single row of dots
//   4–8:  two rows — top ⌈signal/2⌉, bottom ⌊signal/2⌋
//   0:    renders nothing (caller should guard, but safe to call)

import SwiftUI

struct GlyphSignalView: View {

    let signal:   Int
    let tileSize: CGFloat
    let color:    Color

    // Shadow to give glyphs depth against varied tile backgrounds
    private let shadowColor = Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0).opacity(0.45)

    var body: some View {
        if signal <= 0 {
            // Blank — no clue to show
            EmptyView()
        } else if signal <= 3 {
            singleRow(count: signal)
        } else {
            let topCount    = (signal + 1) / 2  // ⌈signal/2⌉
            let bottomCount = signal / 2          // ⌊signal/2⌋
            VStack(spacing: 1) {
                singleRow(count: topCount)
                singleRow(count: bottomCount)
            }
        }
    }

    // MARK: - Helpers

    /// Renders `count` pip characters in one horizontal line.
    @ViewBuilder
    private func singleRow(count: Int) -> some View {
        Text(String(repeating: "●", count: count))
            .font(.system(size: dotSize, weight: .bold, design: .default))
            .foregroundColor(color)
            .shadow(color: shadowColor, radius: 0.5, x: 0, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// Scale dot size to tile — 4-8 signal uses a slightly smaller dot to fit two rows.
    private var dotSize: CGFloat {
        if signal <= 3 {
            return tileSize * 0.38
        } else {
            return tileSize * 0.26
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        ForEach(1...8, id: \.self) { n in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.sRGB, red: 0.85, green: 0.80, blue: 0.70))
                    .frame(width: 48, height: 48)
                GlyphSignalView(signal: n, tileSize: 48, color: .indigo)
            }
        }
    }
    .padding()
}
