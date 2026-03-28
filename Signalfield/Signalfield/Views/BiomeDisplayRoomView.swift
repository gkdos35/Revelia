// Signalfield/Views/BiomeDisplayRoomView.swift
//
// A single biome's display room inside the Specimen Cabinet.
// Shows all specimens for the biome on glass platforms arranged in a scrollable grid.
//
// Navigation:
//   SpecimenCabinetView  →  BiomeDisplayRoomView  (tapped from cabinet hub)
//   BiomeDisplayRoomView  →  SpecimenCabinetView  (back button)
//
// Ordering (matches SpecimenCatalog.buildAll order):
//   Square-campaign level specimens first (in level order),
//   then hex-campaign level specimens (in level order),
//   then rare specimens (square rare, hex rare).
//
// Detail view: tapping a collected platform shows a centered modal card.
// Uncollected platforms are shown as empty glass with a faint "?".
// Rare specimens get a larger platform with a subtle gold border.

import SwiftUI

// MARK: - BiomeDisplayRoomView

struct BiomeDisplayRoomView: View {

    @EnvironmentObject private var specimenStore: SpecimenStore

    /// Biome index, 0–8.
    let biomeId: Int

    /// Called when the player taps the Back button to return to the cabinet hub.
    var onBack: () -> Void

    /// If non-nil, this specimen's platform gets a golden shimmer on room entry.
    /// Defaults to nil (no shimmer).
    var newestSpecimenId: String? = nil

    // MARK: - Derived

    private var theme: BiomeTheme {
        BiomeTheme.theme(for: biomeId)
    }

    private var biomeName: String {
        BiomeInfo.squareBiomes[biomeId].name
    }

    /// All specimens for this biome, in catalog order:
    /// square-campaign levels → hex-campaign levels → rares.
    private var orderedSpecimens: [Specimen] {
        SpecimenCatalog.specimens(for: biomeId)
    }

    private var collectedCount: Int {
        specimenStore.unlockedCount(for: biomeId)
    }

    private var totalCount: Int {
        orderedSpecimens.count
    }

    // MARK: - Selection state (String ID avoids Equatable requirement on Specimen)

    @State private var selectedSpecimenId: String? = nil

    private var selectedSpecimen: Specimen? {
        guard let sid = selectedSpecimenId else { return nil }
        return orderedSpecimens.first { $0.id == sid }
    }

    // MARK: - Shimmer state

    /// The specimen whose platform gets a golden entry shimmer.
    /// Set from newestSpecimenId on appear, cleared after 3s.
    @State private var activeShimmerSpecimenId: String? = nil

    // MARK: - Body

    var body: some View {
        // Background applied via .background(...ignoresSafeArea()) so the image
        // bleeds behind the title bar while the ZStack respects the safe area —
        // content (header, back button) starts cleanly below the title bar.
        ZStack {
            // ── Biome-tinted dust motes ───────────────────────────────────
            BiomeDustView(tintColor: theme.pinColor)
                .allowsHitTesting(false)

            // ── Main content ──────────────────────────────────────────────
            VStack(spacing: 0) {
                roomHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                specimenGrid
            }

            // ── Detail modal overlay ──────────────────────────────────────
            // Uses ZStack + `if` pattern (never opacity/hidden) per safe-coding rules.
            if selectedSpecimenId != nil, let spec = selectedSpecimen {
                specimenDetailOverlay(spec)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(roomBackground.ignoresSafeArea())
        .onAppear {
            guard let sid = newestSpecimenId else { return }
            activeShimmerSpecimenId = sid
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.6)) {
                    activeShimmerSpecimenId = nil
                }
            }
        }
    }

    // MARK: - Background

    private var roomBackground: some View {
        ZStack {
            // Dark base
            Color(red: 0.05, green: 0.05, blue: 0.09)
            // Cabinet background image when available
            Image("CabinetBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.70)
            // Biome ambient glow — room bathed in the biome's light.
            // Radius expanded to 420pt so the tint reaches the window edges.
            RadialGradient(
                gradient: Gradient(colors: [
                    theme.pinColor.opacity(0.26),
                    theme.pinColor.opacity(0.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
        }
        // Note: .ignoresSafeArea() applied by caller via
        // .background(roomBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var roomHeader: some View {
        ZStack(alignment: .topLeading) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Collection")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.70))
            }
            .buttonStyle(.plain)

            // Biome name + count
            VStack(spacing: 5) {
                Text(biomeName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.pinColor)
                    .shadow(color: theme.pinColor.opacity(0.40), radius: 6, x: 0, y: 0)

                Text("\(collectedCount) / \(totalCount) specimens")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Specimen Grid

    private var specimenGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                spacing: 20
            ) {
                ForEach(orderedSpecimens) { spec in
                    let collected = specimenStore.isUnlocked(spec.id)
                    let isNewest  = activeShimmerSpecimenId == spec.id

                    SpecimenPlatformView(
                        specimen:  spec,
                        collected: collected,
                        biomeTheme: theme,
                        isNewest:  isNewest
                    )
                    .onTapGesture {
                        if collected {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
                                selectedSpecimenId = spec.id
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Detail Overlay

    @ViewBuilder
    private func specimenDetailOverlay(_ specimen: Specimen) -> some View {
        // Full-screen dismissable backdrop
        Color.black.opacity(0.52)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.25)) {
                    selectedSpecimenId = nil
                }
            }

        // Centered detail card
        SpecimenDetailCard(
            specimen:  specimen,
            biomeId:   biomeId
        )
        .transition(.scale(scale: 0.82).combined(with: .opacity))
        .allowsHitTesting(true)
        .onTapGesture { } // consume taps on card so they don't fall through to backdrop
    }
}

// MARK: - SpecimenPlatformView

/// A single specimen slot in the biome display room.
///
/// Collected: glass platform with specimen image + biome-tinted glow + name label.
/// Uncollected: empty glass platform with a faint "?" — shows the slot exists.
/// Rare: larger platform (70×80pt) with a subtle gold border.
/// Newest (on room entry): brief golden shimmer animation for ~3s.
private struct SpecimenPlatformView: View {

    let specimen:   Specimen
    let collected:  Bool
    let biomeTheme: BiomeTheme
    let isNewest:   Bool

    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    // Platform geometry — rare specimens get slightly more space
    private var platformWidth:  CGFloat { specimen.isRare ? 70 : 60 }
    private var platformHeight: CGFloat { specimen.isRare ? 80 : 70 }
    private var imageSize:      CGFloat { specimen.isRare ? 52 : 44 }

    // MARK: Shimmer state

    @State private var shimmerOpacity: Double = 0

    // MARK: Body

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Golden entry shimmer (collected + newest only)
                if isNewest {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(gold.opacity(shimmerOpacity))
                        .frame(width: platformWidth + 8, height: platformHeight + 8)
                        .blur(radius: 6)
                }

                // Glass platform surface — raised to 0.09 for visible glass effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.09))

                // Top reflection — simulates light catching the glass edge
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint:   .bottom
                            )
                        )
                        .frame(height: 14)
                        .padding(.horizontal, 1)
                        .padding(.top, 1)
                    Spacer()
                }

                // Platform border — raised opacity + lineWidth to read on dark bg
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        specimen.isRare
                            ? gold.opacity(0.40)
                            : Color.white.opacity(0.22),
                        lineWidth: specimen.isRare ? 1.2 : 1.0
                    )

                // Platform content
                if collected {
                    Image(specimen.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("?")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.18))
                }
            }
            .frame(width: platformWidth, height: platformHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // Biome-tinted glow BEHIND the platform — always present but
            // stronger for collected, subtle for uncollected slots.
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [
                        biomeTheme.pinColor.opacity(collected ? 0.35 : 0.12),
                        biomeTheme.pinColor.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: platformWidth * 0.8
                )
                .blur(radius: 8)
                .frame(width: platformWidth + 24, height: platformHeight + 20)
            )

            // Specimen name — warm white, shown for collected specimens
            if collected {
                Text(specimen.name)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.97, blue: 0.90).opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: platformWidth + 12)
            }
        }
        .onAppear {
            guard isNewest else { return }
            // Golden shimmer pulse on room entry
            withAnimation(.easeInOut(duration: 0.55).repeatCount(4, autoreverses: true)) {
                shimmerOpacity = 0.45
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.50)) {
                    shimmerOpacity = 0
                }
            }
        }
    }
}

// MARK: - SpecimenDetailCard

/// Centered modal card shown when tapping a collected specimen.
/// Appears with a spring scale-up; dismiss by tapping outside the card.
private struct SpecimenDetailCard: View {

    let specimen: Specimen
    let biomeId:  Int

    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }
    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    var body: some View {
        VStack(spacing: 14) {
            // Rare badge (above name, if applicable)
            if specimen.isRare {
                Text("Rare")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(gold.opacity(0.15))
                            .overlay(Capsule().strokeBorder(gold.opacity(0.35), lineWidth: 0.5))
                    )
            }

            // Specimen image with soft watercolor halo
            ZStack {
                // Biome-tinted watercolor stain behind image
                Ellipse()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: theme.signalColor.opacity(0.35), location: 0.0),
                                .init(color: theme.signalColor.opacity(0.12), location: 0.50),
                                .init(color: theme.signalColor.opacity(0.00), location: 1.0)
                            ]),
                            center: UnitPoint(x: 0.45, y: 0.50),
                            startRadius: 0,
                            endRadius: 75
                        )
                    )
                    .frame(width: 160, height: 130)
                    .blur(radius: 6)

                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 4)
            }

            // Specimen name
            Text(specimen.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .opacity(0.90)
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.signalColor.opacity(0.04))
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 10)
        .frame(maxWidth: 300)
    }
}

// MARK: - BiomeDustView

/// Ambient floating dust motes for the biome display room.
/// Identical in structure to CabinetDustView but tinted to the biome's pin color
/// at very low opacity for a subtle biome-specific atmosphere.
private struct BiomeDustView: View {

    let tintColor: Color
    private let motes: [RoomMoteData]
    @State private var animating: Bool = false

    init(tintColor: Color) {
        self.tintColor = tintColor
        var rng  = RoomSeededRandom(seed: 0xD15B1A4)
        var list = [RoomMoteData]()
        for i in 0..<8 {
            list.append(RoomMoteData(
                id:       i,
                size:     CGFloat.random(in: 2.0...4.5, using: &rng),
                startX:   CGFloat.random(in: 0.05...0.95, using: &rng),
                startY:   CGFloat.random(in: 0.05...0.95, using: &rng),
                driftX:   CGFloat.random(in: -20...20,    using: &rng),
                driftY:   CGFloat.random(in: -50...(-6),  using: &rng),
                opacity:  Double.random( in: 0.06...0.13, using: &rng),
                duration: Double.random( in: 6.0...10.0,  using: &rng),
                delay:    Double.random( in: 0.0...3.5,   using: &rng)
            ))
        }
        self.motes = list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(motes) { m in
                    Circle()
                        .fill(tintColor)
                        .frame(width: m.size, height: m.size)
                        .opacity(animating ? m.opacity : 0)
                        .offset(
                            x: m.startX * geo.size.width  + (animating ? m.driftX : 0),
                            y: m.startY * geo.size.height + (animating ? m.driftY : 0)
                        )
                        .animation(
                            .easeInOut(duration: m.duration)
                                .repeatForever(autoreverses: true)
                                .delay(m.delay),
                            value: animating
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Room Support Types

private struct RoomMoteData: Identifiable {
    let id:       Int
    let size:     CGFloat
    let startX:   CGFloat
    let startY:   CGFloat
    let driftX:   CGFloat
    let driftY:   CGFloat
    let opacity:  Double
    let duration: Double
    let delay:    Double
}

private struct RoomSeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
