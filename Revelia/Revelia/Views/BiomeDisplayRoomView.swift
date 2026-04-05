// Revelia/Views/BiomeDisplayRoomView.swift
//
// A single biome's display room inside the Specimen Cabinet.
// Specimens are arranged on larger horizontal shelves so the room reads like
// a naturalist display wall rather than a dense grid of floating icons.

import SwiftUI

// MARK: - BiomeDisplayRoomView

struct BiomeDisplayRoomView: View {

    @EnvironmentObject private var specimenStore: SpecimenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let biomeId: Int
    var onBack: () -> Void
    var newestSpecimenId: String? = nil

    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }
    private var biomeName: String { BiomeInfo.squareBiomes[biomeId].name }

    private var orderedSpecimens: [Specimen] {
        SpecimenCatalog.specimens(for: biomeId)
    }

    private var squareSpecimens: [Specimen] {
        orderedSpecimens.filter { !$0.isHex && !$0.isRare }
    }

    private var hexSpecimens: [Specimen] {
        orderedSpecimens.filter { $0.isHex && !$0.isRare }
    }

    private var rareSpecimens: [Specimen] {
        orderedSpecimens.filter(\.isRare)
    }

    private var collectedCount: Int {
        specimenStore.unlockedCount(for: biomeId)
    }

    private var totalCount: Int {
        orderedSpecimens.count
    }

    @State private var selectedSpecimenId: String? = nil
    @State private var activeShimmerSpecimenId: String? = nil

    private var selectedSpecimen: Specimen? {
        guard let sid = selectedSpecimenId else { return nil }
        return orderedSpecimens.first { $0.id == sid }
    }

    var body: some View {
        ZStack {
            BiomeDustView(tintColor: theme.pinColor)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                roomHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                roomContent
            }

            if let specimen = selectedSpecimen {
                specimenDetailOverlay(specimen)
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

    private var roomBackground: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.09)

            Image("CabinetBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.72)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    theme.pinColor.opacity(0.24),
                    theme.pinColor.opacity(0.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 480
            )
        }
    }

    private var roomHeader: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Collection")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.72))
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Text(biomeName)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.pinColor)
                    .shadow(color: theme.pinColor.opacity(0.36), radius: 6, x: 0, y: 0)

                Text("\(collectedCount) / \(totalCount) specimens")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var roomContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                RareDisplaySection(
                    specimens: rareSpecimens,
                    biomeTheme: theme,
                    isUnlocked: { specimenStore.isUnlocked($0.id) },
                    isNewest: { activeShimmerSpecimenId == $0.id },
                    onSelect: selectSpecimen
                )

                ShelfSectionView(
                    title: "Square Collection",
                    subtitle: "Field specimens recovered from the square campaign.",
                    specimens: squareSpecimens,
                    biomeTheme: theme,
                    isUnlocked: { specimenStore.isUnlocked($0.id) },
                    isNewest: { activeShimmerSpecimenId == $0.id },
                    onSelect: selectSpecimen
                )

                ShelfSectionView(
                    title: "Hex Collection",
                    subtitle: "Companion discoveries recovered from the hex campaign.",
                    specimens: hexSpecimens,
                    biomeTheme: theme,
                    isUnlocked: { specimenStore.isUnlocked($0.id) },
                    isNewest: { activeShimmerSpecimenId == $0.id },
                    onSelect: selectSpecimen
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private func specimenDetailOverlay(_ specimen: Specimen) -> some View {
        Color.black.opacity(0.54)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.22)) {
                    selectedSpecimenId = nil
                }
            }

        SpecimenPreviewCard(specimen: specimen, biomeTheme: theme)
            .transition(.scale(scale: 0.84).combined(with: .opacity))
            .allowsHitTesting(true)
            .onTapGesture { }
    }

    private func selectSpecimen(_ specimen: Specimen) {
        guard specimenStore.isUnlocked(specimen.id) else { return }
        if reduceMotion {
            selectedSpecimenId = specimen.id
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedSpecimenId = specimen.id
            }
        }
    }
}

// MARK: - RareDisplaySection

private struct RareDisplaySection: View {
    let specimens: [Specimen]
    let biomeTheme: BiomeTheme
    let isUnlocked: (Specimen) -> Bool
    let isNewest: (Specimen) -> Bool
    let onSelect: (Specimen) -> Void

    var body: some View {
        MuseumPanel(theme: biomeTheme) {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(
                    title: "Centerpieces",
                    subtitle: "Rare cabinet rewards earned by completing each campaign in this biome."
                )

                ZStack(alignment: .bottom) {
                    CabinetShelfArtwork(
                        width: shelfWidth(for: specimens.count),
                        tint: biomeTheme.pinColor,
                        highlightOpacity: 0.18,
                        shadowOpacity: 0.30
                    )

                    HStack(alignment: .bottom, spacing: 18) {
                        ForEach(specimens) { specimen in
                            SpecimenShelfSlot(
                                specimen: specimen,
                                biomeTheme: biomeTheme,
                                collected: isUnlocked(specimen),
                                isNewest: isNewest(specimen),
                                isFeatured: false,
                                onSelect: { onSelect(specimen) }
                            )
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shelfWidth(for count: Int) -> CGFloat {
        switch count {
        case 1: return 230
        case 2: return 390
        default: return 560
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
        }
    }
}

// MARK: - ShelfSectionView

private struct ShelfSectionView: View {
    let title: String
    let subtitle: String
    let specimens: [Specimen]
    let biomeTheme: BiomeTheme
    let isUnlocked: (Specimen) -> Bool
    let isNewest: (Specimen) -> Bool
    let onSelect: (Specimen) -> Void

    private var rows: [[Specimen]] { specimens.chunked(into: 3) }

    var body: some View {
        MuseumPanel(theme: biomeTheme) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.58))
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    ZStack(alignment: .bottom) {
                        CabinetShelfArtwork(
                            width: shelfWidth(for: row.count, isLastRow: index == rows.count - 1),
                            tint: biomeTheme.pinColor,
                            highlightOpacity: 0.18,
                            shadowOpacity: 0.28
                        )
                        .offset(y: index == rows.count - 1 ? 2 : 0)

                        HStack(alignment: .bottom, spacing: 18) {
                            ForEach(row) { specimen in
                                SpecimenShelfSlot(
                                    specimen: specimen,
                                    biomeTheme: biomeTheme,
                                    collected: isUnlocked(specimen),
                                    isNewest: isNewest(specimen),
                                    isFeatured: false,
                                    onSelect: { onSelect(specimen) }
                                )
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func shelfWidth(for count: Int, isLastRow: Bool = false) -> CGFloat {
        if isLastRow {
            return 560
        }
        switch count {
        case 1: return 230
        case 2: return 390
        default: return 560
        }
    }
}

// MARK: - SpecimenShelfSlot

private struct SpecimenShelfSlot: View {
    let specimen: Specimen
    let biomeTheme: BiomeTheme
    let collected: Bool
    let isNewest: Bool
    let isFeatured: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hovering = false
    @State private var shimmerOpacity = 0.0

    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    private var cardWidth: CGFloat { isFeatured ? 210 : 165 }
    private var imageHeight: CGFloat { isFeatured ? 142 : 118 }

    private var labelText: String {
        if collected { return specimen.name }
        return specimen.isRare ? "Undiscovered Rare Specimen" : "Undiscovered Specimen"
    }

    var body: some View {
        Button(action: {
            if collected {
                onSelect()
            }
        }) {
            VStack(spacing: 12) {
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.22))
                        .frame(width: cardWidth * 0.58, height: 14)
                        .blur(radius: 5)
                        .offset(y: 8)

                    if isNewest {
                        Ellipse()
                            .fill(gold.opacity(shimmerOpacity))
                            .frame(width: cardWidth * 0.88, height: imageHeight * 1.05)
                            .blur(radius: 12)
                    }

                    VStack(spacing: 12) {
                        ZStack {
                            Ellipse()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            biomeTheme.pinColor.opacity(collected ? 0.28 : 0.10),
                                            biomeTheme.pinColor.opacity(0.0)
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: imageHeight * 0.86
                                    )
                                )
                                .frame(width: cardWidth * 0.70, height: imageHeight * 0.88)
                                .blur(radius: 10)

                            if collected {
                                Image(specimen.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: cardWidth * 0.68, maxHeight: imageHeight)
                                    .shadow(color: .black.opacity(0.30), radius: 10, x: 0, y: 6)
                            } else {
                                MissingSpecimenSilhouette()
                                    .frame(width: cardWidth * 0.42, height: imageHeight * 0.82)
                                    .foregroundStyle(Color.white.opacity(0.18))
                            }
                        }
                        .frame(height: imageHeight)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .frame(width: cardWidth, height: imageHeight + 18)
                    .scaleEffect(hovering && !reduceMotion ? 1.035 : 1.0)
                    .shadow(color: biomeTheme.pinColor.opacity(hovering ? 0.20 : 0.12), radius: hovering ? 18 : 10, x: 0, y: 8)
                    .overlay(alignment: .topTrailing) {
                        if collected {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(hovering ? 0.84 : 0.0))
                                .padding(12)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
                            }
                    }
                }

                VStack(spacing: 6) {
                    Text(labelText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.97, blue: 0.91).opacity(collected ? 0.92 : 0.58))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: cardWidth - 10)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(Color.black.opacity(0.22))
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!collected)
        .onHover { inside in
            hovering = inside && collected
        }
        .onAppear {
            guard isNewest else { return }
            if reduceMotion {
                shimmerOpacity = 0.28
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    shimmerOpacity = 0
                }
            } else {
                withAnimation(.easeInOut(duration: 0.55).repeatCount(4, autoreverses: true)) {
                    shimmerOpacity = 0.42
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        shimmerOpacity = 0
                    }
                }
            }
        }
        .frame(width: cardWidth)
        .accessibilityLabel(labelText)
        .accessibilityValue(collected ? "Discovered" : "Undiscovered")
        .accessibilityHint(collected ? "Opens a larger preview." : "Not yet collected.")
    }
}

// MARK: - SpecimenPreviewCard

private struct SpecimenPreviewCard: View {
    let specimen: Specimen
    let biomeTheme: BiomeTheme

    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    var body: some View {
        VStack(spacing: 18) {
            if specimen.isRare {
                Text(specimen.isHex ? "Hex centerpiece" : "Square centerpiece")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(gold.opacity(0.14))
                            .overlay(Capsule().strokeBorder(gold.opacity(0.34), lineWidth: 0.7))
                    )
            }

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                biomeTheme.signalColor.opacity(0.34),
                                biomeTheme.signalColor.opacity(0.06),
                                biomeTheme.signalColor.opacity(0.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 175
                        )
                    )
                    .frame(width: 320, height: 220)
                    .blur(radius: 12)

                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 280, height: 250)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    )

                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 230, maxHeight: 210)
                    .shadow(color: .black.opacity(0.36), radius: 18, x: 0, y: 10)
            }

            Text(specimen.name)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            Text("Recovered specimen")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.54))
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .opacity(0.94)
            RoundedRectangle(cornerRadius: 28)
                .fill(biomeTheme.pinColor.opacity(0.07))
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.46), radius: 28, x: 0, y: 14)
        .frame(maxWidth: 420)
        .padding(20)
    }
}

// MARK: - MuseumPanel

private struct MuseumPanel<Content: View>: View {
    let theme: BiomeTheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.93)
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.pinColor.opacity(0.06))
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
        }
        .shadow(color: theme.pinColor.opacity(0.12), radius: 16, x: 0, y: 8)
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

// MARK: - BiomeDustView

private struct BiomeDustView: View {
    let tintColor: Color

    private let motes: [RoomMoteData]
    @State private var animating = false

    init(tintColor: Color) {
        self.tintColor = tintColor
        var rng = RoomSeededRandom(seed: 0xD15B1A4)
        var list = [RoomMoteData]()
        for i in 0..<8 {
            list.append(RoomMoteData(
                id: i,
                size: CGFloat.random(in: 2.0...4.5, using: &rng),
                startX: CGFloat.random(in: 0.05...0.95, using: &rng),
                startY: CGFloat.random(in: 0.05...0.95, using: &rng),
                driftX: CGFloat.random(in: -20...20, using: &rng),
                driftY: CGFloat.random(in: -50...(-6), using: &rng),
                opacity: Double.random(in: 0.06...0.13, using: &rng),
                duration: Double.random(in: 6.0...10.0, using: &rng),
                delay: Double.random(in: 0.0...3.5, using: &rng)
            ))
        }
        self.motes = list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(motes) { mote in
                    Circle()
                        .fill(tintColor)
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

private struct RoomMoteData: Identifiable {
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
