// Revelia/Views/HUDView.swift

import SwiftUI

/// Heads-up display showing game stats: timer, actions, live score, hazard counter.
struct HUDView: View {
    @ObservedObject var viewModel: GameViewModel
    var onOpenSettings: () -> Void

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var audioManager: AudioManager

    var body: some View {
        GeometryReader { proxy in
            regularLayout(for: proxy.size.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .frame(height: 42)
    }

    private func regularLayout(for width: CGFloat) -> some View {
        HStack(spacing: rowSpacing(for: width)) {
            leadingStats(for: width)

            Spacer(minLength: spacerMinLength(for: width))

            trailingControls(for: width)
        }
    }

    private func leadingStats(for width: CGFloat) -> some View {
        HStack(spacing: itemSpacing(for: width)) {
            statItem(systemImage: "clock", color: .secondary, width: width) {
                Text(formattedTime)
                    .monospacedDigit()
            }

            statItem(systemImage: "hand.tap", color: .secondary, width: width) {
                Text("\(viewModel.stats.totalActions)")
                    .monospacedDigit()
            }

            statItem(systemImage: "exclamationmark.triangle", color: .orange, width: width) {
                Text("\(hazardsRemaining)")
                    .monospacedDigit()
            }

            if viewModel.beaconChargesRemaining > 0 || viewModel.isBeaconTargeting {
                beaconButton(width: width)
            }

            if viewModel.conductorChargesRemaining > 0 || viewModel.isConductorTargeting {
                conductorButton(width: width)
            }
        }
    }

    private func trailingControls(for width: CGFloat) -> some View {
        HStack(spacing: itemSpacing(for: width)) {
            statItem(systemImage: "star", color: .yellow, width: width) {
                Text("\(liveScore)")
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            stateIndicator
                .fixedSize(horizontal: true, vertical: false)

            settingsButton(width: width)
        }
        .layoutPriority(1)
    }

    private func beaconButton(width: CGFloat) -> some View {
        Button(action: {
            if viewModel.isBeaconTargeting {
                viewModel.cancelBeaconTargeting()
            } else {
                viewModel.activateBeacon()
                audioManager.play(.beaconTarget)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(viewModel.isBeaconTargeting ? .white : .cyan)
                Text("\(viewModel.beaconChargesRemaining)")
                    .monospacedDigit()
                    .foregroundColor(viewModel.isBeaconTargeting ? .white : .primary)
            }
            .padding(.horizontal, chipHorizontalPadding(for: width))
            .padding(.vertical, chipVerticalPadding(for: width))
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

    private func conductorButton(width: CGFloat) -> some View {
        Button(action: {
            if viewModel.isConductorTargeting {
                viewModel.cancelConductorTargeting()
            } else {
                viewModel.activateConductor()
                audioManager.play(.conductorTarget)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(viewModel.isConductorTargeting ? .white : conductorColor)
                Text("\(viewModel.conductorChargesRemaining)")
                    .monospacedDigit()
                    .foregroundColor(viewModel.isConductorTargeting ? .white : .primary)
            }
            .padding(.horizontal, chipHorizontalPadding(for: width))
            .padding(.vertical, chipVerticalPadding(for: width))
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

    private func settingsButton(width: CGFloat) -> some View {
        Button(action: {
            audioManager.playMenuClick()
            onOpenSettings()
        }) {
            Image(systemName: "gearshape")
                .foregroundColor(.secondary)
                .font(width < 620 ? .body : .body)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private func statItem<Content: View>(
        systemImage: String,
        color: Color,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            content()
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func rowSpacing(for width: CGFloat) -> CGFloat {
        width < 700 ? 8 : 16
    }

    private func itemSpacing(for width: CGFloat) -> CGFloat {
        width < 700 ? 8 : 12
    }

    private func spacerMinLength(for width: CGFloat) -> CGFloat {
        width < 700 ? 0 : 8
    }

    private func chipHorizontalPadding(for width: CGFloat) -> CGFloat {
        width < 700 ? 6 : 8
    }

    private func chipVerticalPadding(for width: CGFloat) -> CGFloat {
        width < 700 ? 3 : 4
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
        return ScoringCalculator.calculateScore(stats: tempStats, level: viewModel.levelSpec)
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
