// Revelia/Views/HighScoresFlowView.swift

import SwiftUI

struct HighScoresFlowView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var leaderboardStore: LeaderboardStore
    @EnvironmentObject private var audioManager: AudioManager

    let onBackToHome: () -> Void

    @State private var selectedCampaign: CampaignSelection? = nil
    @State private var selectedBiome: BiomeInfo? = nil
    @State private var selectedLevel: LevelSpec? = nil

    private let parchmentLight = Color(.sRGB, red: 0.97, green: 0.93, blue: 0.84)
    private let parchmentDark = Color(.sRGB, red: 0.92, green: 0.86, blue: 0.74)
    private let sepiaStroke = Color(.sRGB, red: 0.58, green: 0.45, blue: 0.30)
    private let inkPrimary = Color(.sRGB, red: 0.18, green: 0.12, blue: 0.06)
    private let inkSecondary = Color(.sRGB, red: 0.42, green: 0.32, blue: 0.20)
    private let cardShape = RoundedRectangle(cornerRadius: 18)
    private let masteryGold = Color(.sRGB, red: 1.000, green: 0.843, blue: 0.000)

    private var hexCampaignUnlocked: Bool {
        progressStore.isCompleted("L74")
    }

    var body: some View {
        ZStack {
            Image("WelcomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.18), .black.opacity(0.48)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
                .frame(width: 540, height: 620)
                .background {
                    ZStack {
                        cardShape
                            .fill(
                                LinearGradient(
                                    colors: [parchmentLight, parchmentDark],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Image("ParchmentCard")
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(1.08)
                            .clipShape(cardShape)

                        cardShape
                            .fill(Color.white.opacity(0.18))

                        cardShape
                            .stroke(sepiaStroke.opacity(0.45), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 10)
                }
                .clipShape(cardShape)
                .overlay(
                    cardShape
                        .stroke(sepiaStroke.opacity(0.18), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let level = selectedLevel {
            LevelLeaderboardView(level: level, onBack: {
                audioManager.playMenuClick()
                selectedLevel = nil
            })
        } else if let biome = selectedBiome {
            biomeLevelsView(for: biome)
        } else if let campaign = selectedCampaign {
            biomeListView(for: campaign)
        } else {
            campaignPickerView
        }
    }

    private var campaignPickerView: some View {
        VStack(spacing: 0) {
            header(title: "High Scores", backLabel: "Home", backAction: {
                audioManager.playMenuClick()
                onBackToHome()
            })

            Divider()
                .background(sepiaStroke.opacity(0.30))

            VStack(spacing: 18) {
                Spacer()

                Text("Choose a campaign")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(inkPrimary)

                campaignButton(for: .square, isEnabled: true)
                campaignButton(for: .hex, isEnabled: hexCampaignUnlocked)

                if !hexCampaignUnlocked {
                    Text("Hex High Scores unlock after finishing The Delta on the square campaign.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(inkSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }

                Spacer()
            }
            .padding(.bottom, 32)
        }
    }

    private func biomeListView(for campaign: CampaignSelection) -> some View {
        let biomes = campaign.biomes

        return VStack(spacing: 0) {
            header(title: campaign.title, backLabel: "Campaigns", backAction: {
                audioManager.playMenuClick()
                selectedCampaign = nil
            })

            Divider()
                .background(sepiaStroke.opacity(0.30))

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(biomes) { biome in
                        Button {
                            audioManager.playMenuClick()
                            selectedBiome = biome
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(biome.name)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                    Text(biomeSummaryText(for: biome))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(inkPrimary)

                                Spacer()

                                if biomeIsFullyMastered(biome) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.black.opacity(0.10))
                                            .frame(width: 198, height: 76)
                                            .blur(radius: 4)

                                        Image("MasteredPlaque")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 190, height: 72)
                                            .clipped()
                                    }
                                    .offset(x: -30)
                                } else {
                                    Image(systemName: biome.icon)
                                        .foregroundStyle(BiomeTheme.theme(for: biome.id).signalColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.42))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(sepiaStroke.opacity(0.20), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }

    private func biomeLevelsView(for biome: BiomeInfo) -> some View {
        VStack(spacing: 0) {
            header(title: biome.name, backLabel: "Biomes", backAction: {
                audioManager.playMenuClick()
                selectedBiome = nil
            })

            Divider()
                .background(sepiaStroke.opacity(0.30))

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(biome.levels) { level in
                        let isUnlocked = progressStore.isUnlocked(level)
                        let hasScores = leaderboardStore.hasEntries(for: level.id)
                        let isEnabled = isUnlocked && hasScores

                        Button {
                            audioManager.playMenuClick()
                            selectedLevel = level
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.displayName)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                    Text(replayTargetText(for: level, isUnlocked: isUnlocked, hasScores: hasScores))
                                        .font(.system(size: 12, design: .rounded))
                                }
                                .foregroundStyle(inkPrimary)

                                Spacer()

                                if let bestEntry = leaderboardStore.bestEntry(for: level.id) {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(LeaderboardFormatting.formattedScore(bestEntry.score))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                        Text(LeaderboardFormatting.formattedRunTime(bestEntry.timeSeconds))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                    }
                                    .foregroundStyle(inkPrimary)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(inkSecondary.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.42))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(sepiaStroke.opacity(0.20), lineWidth: 1)
                            )
                            .opacity(isEnabled ? 1.0 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isEnabled)
                    }
                }
                .padding(20)
            }
        }
    }

    private func header(title: String, backLabel: String, backAction: @escaping () -> Void) -> some View {
        HStack {
            Button(action: backAction) {
                Label(backLabel, systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(inkSecondary)

            Spacer()

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(inkPrimary)

            Spacer()

            Color.clear
                .frame(width: 72, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func campaignButton(for campaign: CampaignSelection, isEnabled: Bool) -> some View {
        Button {
            audioManager.playMenuClick()
            selectedCampaign = campaign
        } label: {
            VStack(spacing: 6) {
                Text(campaign.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(campaign.subtitle)
                    .font(.system(size: 12, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 280, height: 74)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? campaign.buttonColor : Color.gray.opacity(0.45))
            )
            .opacity(isEnabled ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func scoredLevels(in biome: BiomeInfo) -> Int {
        biome.levels.count(where: { leaderboardStore.hasEntries(for: $0.id) })
    }

    private func biomeSummaryText(for biome: BiomeInfo) -> String {
        let scored = scoredLevels(in: biome)
        let earnedStars = biome.levels.reduce(0) { $0 + progressStore.bestStars(for: $1.id) }
        let totalStars = biome.totalStarsPossible
        return "\(scored)/\(biome.levels.count) scored · \(earnedStars)/\(totalStars) stars"
    }

    private func biomeIsFullyMastered(_ biome: BiomeInfo) -> Bool {
        scoredLevels(in: biome) == biome.levels.count &&
        biome.levels.allSatisfy { progressStore.bestStars(for: $0.id) == 3 }
    }

    private func replayTargetText(for level: LevelSpec, isUnlocked: Bool, hasScores: Bool) -> String {
        if !isUnlocked {
            return "Locked"
        }
        if !hasScores {
            return "No wins recorded yet"
        }

        let bestStars = progressStore.bestStars(for: level.id)
        if bestStars < 3 {
            return "\(bestStars)★ best · 3★ available"
        }

        guard let bestEntry = leaderboardStore.bestEntry(for: level.id) else {
            return "View leaderboard"
        }

        let parScore = ScoringCalculator.previewParScore(for: level)
        let parTimeSeconds = Double(level.parTimeSeconds)

        if bestEntry.score < parScore && bestEntry.timeSeconds > parTimeSeconds {
            return "Beat par score or time"
        }
        if bestEntry.score < parScore {
            return "Beat par score"
        }
        if bestEntry.timeSeconds > parTimeSeconds {
            return "Beat par time"
        }
        return "Mastered"
    }
}

private enum CampaignSelection {
    case square
    case hex

    var title: String {
        switch self {
        case .square: return "Square Campaign"
        case .hex: return "Hex Campaign"
        }
    }

    var subtitle: String {
        switch self {
        case .square: return "Levels 1–74"
        case .hex: return "Levels 75–148"
        }
    }

    var buttonColor: Color {
        switch self {
        case .square:
            return Color(red: 0x7A / 255.0, green: 0xAA / 255.0, blue: 0x58 / 255.0)
        case .hex:
            return Color(red: 0x4E / 255.0, green: 0x79 / 255.0, blue: 0x91 / 255.0)
        }
    }

    var biomes: [BiomeInfo] {
        switch self {
        case .square: return BiomeInfo.squareBiomes
        case .hex: return BiomeInfo.hexBiomes
        }
    }
}
