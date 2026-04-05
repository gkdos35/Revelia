// Revelia/Views/LevelLeaderboardView.swift

import SwiftUI

struct LevelLeaderboardView: View {
    @EnvironmentObject private var leaderboardStore: LeaderboardStore
    @Environment(\.dismiss) private var dismiss

    let level: LevelSpec
    var onBack: (() -> Void)? = nil
    var showsCloseButton: Bool = false

    private let parchmentLight = Color(.sRGB, red: 0.97, green: 0.93, blue: 0.84)
    private let parchmentDark = Color(.sRGB, red: 0.92, green: 0.86, blue: 0.74)
    private let sepiaStroke = Color(.sRGB, red: 0.58, green: 0.45, blue: 0.30)
    private let inkPrimary = Color(.sRGB, red: 0.18, green: 0.12, blue: 0.06)
    private let inkSecondary = Color(.sRGB, red: 0.42, green: 0.32, blue: 0.20)

    private var entries: [LeaderboardEntry] {
        leaderboardStore.entries(for: level.id)
    }

    var body: some View {
        ZStack {
            Image("SettingsBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Divider()
                    .background(sepiaStroke.opacity(0.30))

                if entries.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()

                        Text("No recorded wins yet")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(inkPrimary)

                        Text("Complete this level to start its local leaderboard.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(inkSecondary.opacity(0.8))

                        Spacer()
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                leaderboardRow(rank: index + 1, entry: entry)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(width: 500, height: 580)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [parchmentLight, parchmentDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(sepiaStroke.opacity(0.45), lineWidth: 1.5)
                    )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            if let onBack {
                Button(action: onBack) {
                    Label("Levels", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(inkSecondary)
            } else {
                Color.clear
                    .frame(width: 64, height: 1)
            }

            Spacer()

            VStack(spacing: 4) {
                Text(level.displayName)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(inkPrimary)

                Text("Top 10 runs")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(inkSecondary)

                if level.gridShape == .hexagonal {
                    Text("Hex campaign")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(inkSecondary.opacity(0.75))
                }
            }

            Spacer()

            if showsCloseButton {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inkSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 28, height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func leaderboardRow(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack(spacing: 16) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(inkPrimary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(LeaderboardFormatting.formattedScore(entry.score))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(inkPrimary)

                if let stars = entry.stars {
                    HStack(spacing: 2) {
                        ForEach(1...3, id: \.self) { star in
                            Image(systemName: star <= stars ? "star.fill" : "star")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(
                                    star <= stars
                                        ? Color(.sRGB, red: 1.000, green: 0.843, blue: 0.000)
                                        : inkSecondary.opacity(0.24)
                                )
                        }
                    }
                }

                Text(LeaderboardFormatting.formattedTimestamp(entry.achievedAt))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(inkSecondary.opacity(0.8))
            }

            Spacer()

            Text(LeaderboardFormatting.formattedRunTime(entry.timeSeconds))
                .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(inkPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(sepiaStroke.opacity(0.20), lineWidth: 1)
        )
    }
}
