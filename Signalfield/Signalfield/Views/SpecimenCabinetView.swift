// Signalfield/Views/SpecimenCabinetView.swift
//
// The Specimen Cabinet hub — a full-screen museum-at-night experience showing
// a 3×3 grid of glass display cases, one per square-campaign biome (0–8).
//
// Navigation flow:
//   BiomeSelectView  →  SpecimenCabinetView  →  BiomeDisplayRoomView
//
// Both SpecimenStore and SpecimenCatalog are read-only here; no mutations happen.
//
// Asset required:
//   Add "CabinetBackground" to Assets.xcassets (dark atmospheric museum image).
//   The view degrades gracefully to a deep dark-navy background if the asset is missing.

import SwiftUI

// MARK: - SpecimenCabinetView

struct SpecimenCabinetView: View {

    @EnvironmentObject private var specimenStore: SpecimenStore

    /// Called when the player taps the Back button to return to the biome map.
    var onBack: () -> Void

    /// Called when the player taps a biome case — passes the biome ID (0–8).
    var onSelectBiome: (Int) -> Void

    /// If non-nil, the case for the biome containing this specimen gets a golden
    /// pulse animation on appear.  Pass the most recently unlocked specimen ID.
    /// Defaults to nil (no pulse shown).
    var newestSpecimenId: String? = nil

    // MARK: - Derived

    private var totalDiscovered: Int {
        specimenStore.unlockedSpecimenIds.count
    }

    /// Biome ID (0–8) of the most recently unlocked specimen, or nil.
    private var newestBiomeId: Int? {
        guard let sid = newestSpecimenId else { return nil }
        return SpecimenCatalog.all.first { $0.id == sid }?.biomeId
    }

    // MARK: - Body

    var body: some View {
        // Background is applied via .background(...ignoresSafeArea()) so the
        // background image bleeds behind the title bar while the ZStack itself
        // respects the safe area — content starts cleanly below the title bar.
        ZStack {
            // ── Ambient dust motes ────────────────────────────────────────
            CabinetDustView()
                .allowsHitTesting(false)

            // ── Main content ──────────────────────────────────────────────
            VStack(spacing: 0) {
                cabinetHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                cabinetGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cabinetBackground.ignoresSafeArea())
    }

    // MARK: - Background

    private var cabinetBackground: some View {
        ZStack {
            // Deep dark-navy base — always present as a safe fallback.
            Color(red: 0.05, green: 0.05, blue: 0.09)
            // Atmospheric background image when available.
            Image("CabinetBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.80)
        }
        // Note: .ignoresSafeArea() is applied by the caller via
        // .background(cabinetBackground.ignoresSafeArea()), NOT here.
        // This keeps the background out of the ZStack's layout calculation.
    }

    // MARK: - Header

    private var cabinetHeader: some View {
        ZStack(alignment: .topLeading) {
            // Back button — top-left
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Map")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.70))
            }
            .buttonStyle(.plain)

            // Title + count — centered
            VStack(spacing: 5) {
                Text("Specimen Collection")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.65), radius: 6, x: 0, y: 1)

                Text("\(totalDiscovered) discovered")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Grid

    private var cabinetGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                spacing: 14
            ) {
                ForEach(0..<9, id: \.self) { biomeId in
                    let theme         = BiomeTheme.theme(for: biomeId)
                    let biomeName     = BiomeInfo.squareBiomes[biomeId].name
                    let allSpecimens  = SpecimenCatalog.specimens(for: biomeId)
                    let totalCount    = allSpecimens.count
                    let collected     = allSpecimens.filter { specimenStore.isUnlocked($0.id) }
                    let previewThree  = Array(collected.prefix(3))
                    let collectedCount = collected.count

                    BiomeCaseView(
                        biomeName:      biomeName,
                        theme:          theme,
                        collectedCount: collectedCount,
                        totalCount:     totalCount,
                        previewSpecimens: previewThree,
                        isNewest:       newestBiomeId == biomeId
                    )
                    .onTapGesture { onSelectBiome(biomeId) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - BiomeCaseView

/// A single glass display case representing one biome's specimen collection.
/// Shows a biome-tinted glow, glass panel, up to 3 specimen previews, biome name,
/// and X/Y collected count.  An optional golden pulse border highlights the most
/// recently unlocked biome for a few seconds.
private struct BiomeCaseView: View {

    let biomeName:      String
    let theme:          BiomeTheme
    let collectedCount: Int
    let totalCount:     Int
    let previewSpecimens: [Specimen]
    let isNewest:       Bool

    // MARK: Pulse state

    @State private var pulsing:    Bool   = false
    @State private var showPulse:  Bool   = false

    // MARK: Gold tint
    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    // MARK: Body

    var body: some View {
        ZStack {
            // ── Glass case panel ──────────────────────────────────────────
            // Raised to 0.09 so the frosted glass surface is clearly visible
            // against the dark atmospheric background.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.09))

            // Top reflection line — light catching the top edge of the glass
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 22)
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
                Spacer()
            }

            // Outer border — raised lineWidth + opacity to read on dark bg
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.0)

            // Golden pulse border — only shown briefly for newest biome
            if showPulse {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(gold.opacity(pulsing ? 0.60 : 0.22), lineWidth: 1.5)
            }

            // ── Case content ──────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Specimen previews (up to 3 tiny thumbnails)
                if !previewSpecimens.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(previewSpecimens) { spec in
                            Image(spec.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.bottom, 10)
                }

                Spacer()

                // Biome name
                Text(biomeName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.pinColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)

                // X/Y count
                Text("\(collectedCount) / \(totalCount)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.bottom, 10)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // ── Biome-tinted radial glow BEHIND the case ─────────────────────
        // Placed after clipShape so the glow isn't clipped — it bleeds
        // softly around the case edges for the "display lit from within" look.
        .background(
            RadialGradient(
                gradient: Gradient(colors: [
                    theme.pinColor.opacity(0.32),
                    theme.pinColor.opacity(0.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 90
            )
            .blur(radius: 12)
            .frame(width: 220, height: 190)
        )
        .shadow(color: theme.pinColor.opacity(0.20), radius: 14, x: 0, y: 5)
        .onAppear {
            guard isNewest else { return }
            showPulse = true
            // Start pulse
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
            // Stop pulse after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    pulsing    = false
                    showPulse  = false
                }
            }
        }
    }
}

// MARK: - CabinetDustView

/// Sparse floating dust motes — ambient museum atmosphere.
/// White/silver at 10–15 % opacity, small (2–4 pt), slow random drift.
/// Seeded so the layout is stable across re-renders.
private struct CabinetDustView: View {

    private let motes: [MoteData]
    @State private var animating: Bool = false

    init() {
        var rng  = CabinetSeededRandom(seed: 0xC4B13E7)
        var list = [MoteData]()
        for i in 0..<9 {
            list.append(MoteData(
                id:       i,
                size:     CGFloat.random(in: 1.8...4.0, using: &rng),
                startX:   CGFloat.random(in: 0.04...0.96, using: &rng),
                startY:   CGFloat.random(in: 0.04...0.96, using: &rng),
                driftX:   CGFloat.random(in: -18...18,    using: &rng),
                driftY:   CGFloat.random(in: -45...(-5),  using: &rng),
                opacity:  Double.random( in: 0.08...0.15, using: &rng),
                duration: Double.random( in: 5.0...9.0,   using: &rng),
                delay:    Double.random( in: 0.0...3.0,   using: &rng)
            ))
        }
        self.motes = list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(motes) { m in
                    Circle()
                        .fill(Color.white)
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

// MARK: - Mote Data

private struct MoteData: Identifiable {
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

// MARK: - CabinetSeededRandom

/// Deterministic XOR-shift RNG for stable dust mote layouts.
private struct CabinetSeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
