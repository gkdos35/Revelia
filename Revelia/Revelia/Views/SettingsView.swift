// Revelia/Views/SettingsView.swift
//
// Full-screen settings panel presented as a .sheet from BiomeSelectView
// and from the HUD during gameplay.
//
// Sections:
//   • Signal Display  — Glyphs / Numbers toggle
//   • Sound           — Enable / Disable
//   • Reset Progress  — Destructive, guarded by alert
//   • Privacy Policy  — Opens the hosted public privacy-policy page in the default browser

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var leaderboardStore: LeaderboardStore

    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false

    // Parchment palette
    private let parchmentLight = Color(.sRGB, red: 0.97, green: 0.93, blue: 0.84)
    private let parchmentDark  = Color(.sRGB, red: 0.92, green: 0.86, blue: 0.74)
    private let sepiaStroke    = Color(.sRGB, red: 0.58, green: 0.45, blue: 0.30)
    private let sepiaBrown     = Color(.sRGB, red: 0.38, green: 0.28, blue: 0.18)
    private let meadowGreen    = Color(red: 0x7A/255, green: 0xAA/255, blue: 0x58/255)
    private let rustRed        = Color(.sRGB, red: 0.72, green: 0.28, blue: 0.18)

    var body: some View {
        ZStack {
            // Full-bleed background art
            Image("SettingsBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            // Centered parchment card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(sepiaBrown)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(sepiaBrown.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 20)

                Divider()
                    .background(sepiaStroke.opacity(0.30))

                // Settings rows
                VStack(spacing: 0) {
                    backgroundMusicRow
                    settingsDivider
                    gameSoundsRow
                    settingsDivider
                    resetRow
                    settingsDivider
                    privacyRow
                }
                .padding(.bottom, 8)
            }
            .frame(width: 320)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [parchmentLight, parchmentDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(sepiaStroke.opacity(0.45), lineWidth: 1.5)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Reset All Progress?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                progressStore.resetAllProgress()
                leaderboardStore.resetAllLeaderboards()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All level completions, stars, local leaderboards, and unlocks will be permanently erased. This cannot be undone.")
        }
    }

    // MARK: - Signal Display Row

    // MARK: - Sound Row

    private var backgroundMusicRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Background Music")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(sepiaBrown)
                Text("Biome loops and screen transitions")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(sepiaBrown.opacity(0.60))
            }

            Spacer()

            Toggle("", isOn: $settingsStore.backgroundMusicEnabled)
                .toggleStyle(.switch)
                .tint(meadowGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var gameSoundsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Game Sounds")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(sepiaBrown)
                Text("Scans, tags, hazards, buttons, and mechanics")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(sepiaBrown.opacity(0.60))
            }

            Spacer()

            Toggle("", isOn: $settingsStore.gameSoundsEnabled)
                .toggleStyle(.switch)
                .tint(meadowGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Reset Row

    private var resetRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reset Progress")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(sepiaBrown)
                Text("Erase all stars, scores, and unlocks")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(sepiaBrown.opacity(0.60))
                Text("Also clears every saved leaderboard entry")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(sepiaBrown.opacity(0.60))
            }

            Spacer()

            Button(action: { showResetConfirm = true }) {
                Text("Reset")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(rustRed)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Privacy Row

    private var privacyRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy Policy")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(sepiaBrown)
            }

            Spacer()

            Button(action: openPrivacyPolicy) {
                HStack(spacing: 4) {
                    Text("View")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(meadowGreen)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(meadowGreen)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var settingsDivider: some View {
        Divider()
            .background(sepiaStroke.opacity(0.20))
            .padding(.horizontal, 16)
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://privacy.sabasetstudios.com") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsStore())
            .environmentObject(ProgressStore())
            .environmentObject(LeaderboardStore())
            .frame(width: 600, height: 700)
    }
}
