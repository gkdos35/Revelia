// Revelia/Views/SpecimenCabinetView.swift
//
// The Specimen Cabinet hub — a full-screen museum-at-night experience showing
// one shelf vignette per biome. Each card acts as a small naturalist display:
// name plaque, featured specimens, count, and subtle case lighting.

import SwiftUI

// MARK: - SpecimenCabinetView

struct SpecimenCabinetView: View {

    @EnvironmentObject private var specimenStore: SpecimenStore

    var onBack: () -> Void
    var onSelectBiome: (Int) -> Void
    var newestSpecimenId: String? = nil

    private var totalDiscovered: Int {
        specimenStore.unlockedSpecimenIds.count
    }

    private var newestBiomeId: Int? {
        guard let sid = newestSpecimenId else { return nil }
        return SpecimenCatalog.all.first { $0.id == sid }?.biomeId
    }

    var body: some View {
        ZStack {
            CabinetDustView()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                cabinetHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                cabinetGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cabinetBackground.ignoresSafeArea())
    }

    private var cabinetBackground: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.09)

            Image("CabinetBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.82)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var cabinetHeader: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Map")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.72))
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Text("Specimen Collection")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.65), radius: 6, x: 0, y: 1)

                Text("\(totalDiscovered) discovered across the cabinet")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var cabinetGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 286), spacing: 28)],
                spacing: 36
            ) {
                ForEach(0..<9, id: \.self) { biomeId in
                    let theme = BiomeTheme.theme(for: biomeId)
                    let biomeName = BiomeInfo.squareBiomes[biomeId].name
                    let allSpecimens = SpecimenCatalog.specimens(for: biomeId)
                    let featuredSpecimens = Array(allSpecimens.filter { specimenStore.isUnlocked($0.id) }.prefix(3))

                    BiomeCaseView(
                        biomeName: biomeName,
                        theme: theme,
                        collectedCount: specimenStore.unlockedCount(for: biomeId),
                        totalCount: allSpecimens.count,
                        featuredSpecimens: featuredSpecimens,
                        isNewest: newestBiomeId == biomeId
                    )
                    .onTapGesture { onSelectBiome(biomeId) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
        }
    }
}

// MARK: - BiomeCaseView

private struct BiomeCaseView: View {

    let biomeName: String
    let theme: BiomeTheme
    let collectedCount: Int
    let totalCount: Int
    let featuredSpecimens: [Specimen]
    let isNewest: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hovering = false
    @State private var pulsing = false
    @State private var showPulse = false

    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)
    private let parchmentBase = Color(.sRGB, red: 0.95, green: 0.90, blue: 0.82)

    private var progressText: String {
        "\(collectedCount)/\(totalCount)"
    }

    private var isComplete: Bool {
        totalCount > 0 && collectedCount == totalCount
    }

    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(parchmentBase.opacity(hovering ? 0.30 : 0.24))

                Image("ParchmentCard")
                    .resizable()
                    .scaledToFill()
                    .opacity(hovering ? 0.34 : 0.28)
                    .scaleEffect(1.08)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.clear,
                                theme.pinColor.opacity(hovering ? 0.14 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)

                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color(red: 0.40, green: 0.28, blue: 0.16).opacity(0.20), lineWidth: 1.2)
                    .padding(1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(biomeName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.07))

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)

                    if showPulse {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(gold.opacity(pulsing ? 0.56 : 0.18), lineWidth: 1.8)
                    }

                    ZStack(alignment: .bottom) {
                        CabinetShelfArtwork(width: 196, tint: theme.pinColor)

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(0..<3, id: \.self) { index in
                                OverviewSpecimenStand(
                                    specimen: featuredSpecimens.element(at: index),
                                    theme: theme
                                )
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .frame(width: 212)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 148)

                Text(progressText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        isComplete
                            ? Color(.sRGB, red: 1.000, green: 0.843, blue: 0.000)
                            : Color.white.opacity(0.84)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(width: 286, height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: theme.pinColor.opacity(hovering ? 0.18 : 0.10), radius: hovering ? 14 : 10, x: 0, y: 6)
        .scaleEffect(hovering && !reduceMotion ? 1.015 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hovering)
        .onHover { inside in
            hovering = inside
        }
        .onAppear {
            guard isNewest else { return }
            showPulse = true
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    pulsing = false
                    showPulse = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(biomeName), \(progressText)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct OverviewSpecimenStand: View {
    let specimen: Specimen?
    let theme: BiomeTheme

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 60, height: 10)
                .blur(radius: 4)
                .offset(y: 2)

            if let specimen {
                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .shadow(color: .black.opacity(0.28), radius: 7, x: 0, y: 5)
            } else {
                MissingSpecimenSilhouette()
                    .frame(width: 58, height: 58)
                    .foregroundStyle(theme.pinColor.opacity(0.16))
            }
        }
        .frame(width: 68, height: 72)
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

private struct MissingSpecimenSilhouette: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 34, height: 36)
                .offset(y: 10)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 24, height: 24)
                .offset(y: -10)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 44, height: 10)
                .offset(y: 26)
        }
    }
}

// MARK: - CabinetDustView

private struct CabinetDustView: View {

    private let motes: [MoteData]
    @State private var animating = false

    init() {
        var rng = CabinetSeededRandom(seed: 0xC4B13E7)
        var list = [MoteData]()
        for i in 0..<9 {
            list.append(MoteData(
                id: i,
                size: CGFloat.random(in: 1.8...4.0, using: &rng),
                startX: CGFloat.random(in: 0.04...0.96, using: &rng),
                startY: CGFloat.random(in: 0.04...0.96, using: &rng),
                driftX: CGFloat.random(in: -18...18, using: &rng),
                driftY: CGFloat.random(in: -45...(-5), using: &rng),
                opacity: Double.random(in: 0.08...0.15, using: &rng),
                duration: Double.random(in: 5.0...9.0, using: &rng),
                delay: Double.random(in: 0.0...3.0, using: &rng)
            ))
        }
        self.motes = list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(motes) { mote in
                    Circle()
                        .fill(Color.white)
                        .frame(width: mote.size, height: mote.size)
                        .opacity(animating ? mote.opacity : 0)
                        .offset(
                            x: mote.startX * geo.size.width + (animating ? mote.driftX : 0),
                            y: mote.startY * geo.size.height + (animating ? mote.driftY : 0)
                        )
                        .animation(
                            .easeInOut(duration: mote.duration)
                                .repeatForever(autoreverses: true)
                                .delay(mote.delay),
                            value: animating
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animating = true }
    }
}

private struct MoteData: Identifiable {
    let id: Int
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let driftX: CGFloat
    let driftY: CGFloat
    let opacity: Double
    let duration: Double
    let delay: Double
}

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

private extension Array {
    func element(at index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
