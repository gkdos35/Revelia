// Signalfield/Views/HUDView.swift

import SwiftUI

/// Heads-up display showing game stats: timer, actions, live score, hazard counter.
struct HUDView: View {
    @ObservedObject var viewModel: GameViewModel

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore

    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 24) {
            // Timer
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formattedTime)
                    .monospacedDigit()
            }

            // Actions count
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .foregroundColor(.secondary)
                Text("\(viewModel.stats.totalActions)")
                    .monospacedDigit()
            }

            // Hazards remaining (total - confirmed tags on hazards)
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("\(hazardsRemaining)")
                    .monospacedDigit()
            }

            // Beacon charges (only shown on fog levels — Biome 1)
            if viewModel.beaconChargesRemaining > 0 || viewModel.isBeaconTargeting {
                Button(action: {
                    if viewModel.isBeaconTargeting {
                        viewModel.cancelBeaconTargeting()
                    } else {
                        viewModel.activateBeacon()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(viewModel.isBeaconTargeting ? .white : .cyan)
                        Text("\(viewModel.beaconChargesRemaining)")
                            .monospacedDigit()
                            .foregroundColor(viewModel.isBeaconTargeting ? .white : .primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isBeaconTargeting
                                  ? Color.cyan.opacity(0.7)
                                  : Color.cyan.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.beaconChargesRemaining == 0 && !viewModel.isBeaconTargeting)
            }

            // Pulse charges (only shown on bioluminescence levels — Biome 2)
            if viewModel.conductorChargesRemaining > 0 || viewModel.isConductorTargeting {
                Button(action: {
                    if viewModel.isConductorTargeting {
                        viewModel.cancelConductorTargeting()
                    } else {
                        viewModel.activateConductor()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(viewModel.isConductorTargeting ? .white : conductorColor)
                        Text("\(viewModel.conductorChargesRemaining)")
                            .monospacedDigit()
                            .foregroundColor(viewModel.isConductorTargeting ? .white : .primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isConductorTargeting
                                  ? conductorColor.opacity(0.7)
                                  : conductorColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.conductorChargesRemaining == 0 && !viewModel.isConductorTargeting)
            }

            Spacer()

            // Live score preview
            HStack(spacing: 6) {
                Image(systemName: "star")
                    .foregroundColor(.yellow)
                Text("\(liveScore)")
                    .monospacedDigit()
            }

            // Game state indicator
            stateIndicator

            // Settings gear — pauses game implicitly while sheet is open
            // TODO: add explicit pause/resume when sound and pause state are wired
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .font(.system(.body, design: .rounded))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(progressStore)
                .frame(width: 600, height: 500)
        }
    }

    // MARK: - Computed Values

    /// Deep teal-green for the bioluminescence pulse button.
    private var conductorColor: Color {
        Color(red: 0.08, green: 0.72, blue: 0.62)
    }

    private var formattedTime: String {
        let total = Int(viewModel.elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var hazardsRemaining: Int {
        let total = viewModel.board.hazardCount
        let tagged = viewModel.board.confirmedHazardCount
        return max(0, total - tagged)
    }

    private var liveScore: Int {
        var tempStats = viewModel.stats
        tempStats.elapsedTimeSeconds = viewModel.elapsedTime
        return ScoringCalculator.calculateScore(stats: tempStats)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.gameState {
        case .waitingForFirstScan:
            Text("Click to start")
                .foregroundColor(.secondary)
                .italic()
        case .playing:
            EmptyView()
        case .paused:
            Text("PAUSED")
                .foregroundColor(.orange)
                .fontWeight(.bold)
        case .won:
            Text("CLEAR!")
                .foregroundColor(.green)
                .fontWeight(.bold)
        case .exploding:
            Text("HAZARD HIT")
                .foregroundColor(.red)
                .fontWeight(.bold)
        case .lost:
            Text("HAZARD HIT")
                .foregroundColor(.red)
                .fontWeight(.bold)
        case .notStarted:
            EmptyView()
        }
    }
}
