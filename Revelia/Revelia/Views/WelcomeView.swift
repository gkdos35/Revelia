// Revelia/Views/WelcomeView.swift
//
// Home / title screen. Shown every time the app launches.
// Player must tap Play to proceed to BiomeSelectView — no auto-advance, no timer.
//
// TitleSplashView is also reused by the home button on BiomeSelectView so the
// player can return to this screen from the map at any time.

import SwiftUI

// MARK: - WelcomeView

struct WelcomeView: View {
    let onComplete: () -> Void
    let onShowHighScores: () -> Void
    var hasSuspendedRun: Bool = false
    var onResumeLastRun: (() -> Void)? = nil

    var body: some View {
        TitleSplashView(
            onDismiss: onComplete,
            onShowHighScores: onShowHighScores,
            hasSuspendedRun: hasSuspendedRun,
            onResumeLastRun: onResumeLastRun
        )
    }
}

// MARK: - TitleSplashView

/// Full-bleed title / home screen.
/// Used on every app launch and via the home button on the campaign map.
/// `onDismiss` is called when the player taps Play or Continue.
struct TitleSplashView: View {
    let onDismiss: () -> Void
    let onShowHighScores: () -> Void
    var hasSuspendedRun: Bool = false
    var onResumeLastRun: (() -> Void)? = nil

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var audioManager: AudioManager

    // Settings sheet
    @State private var showSettings      = false
    // How to Play sheet
    @State private var showHowToPlay     = false
    // Primary button press animation
    @State private var primaryPressed    = false

    // Colour constants
    private let meadowGreen = Color(red: 0x7A / 255.0, green: 0xAA / 255.0, blue: 0x58 / 255.0)

    private func logoWidth(for size: CGSize) -> CGFloat {
        min(size.width * 2.1875, 3850)
    }

    private func logoHeight(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.84, 385), 1330)
    }

    /// True if the player has completed at least one level.
    private var hasProgress: Bool {
        progressStore.data.levelRecords.values.contains { $0.completed }
    }

    var body: some View {
        // GeometryReader wraps the whole view so geo.size.width is available
        // for the logo calculation without collapsing the VStack layout.
        // The ZStack is explicitly framed to match geo dimensions, which fixes
        // GeometryReader's default top-leading child alignment.
        GeometryReader { geo in
            ZStack {
                // Full-bleed background art
                Image("WelcomeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Subtle dark vignette so text pops
                LinearGradient(
                    colors: [.black.opacity(0.10), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint:   .bottom
                )
                .ignoresSafeArea()

                // Floating particles (non-interactive)
                ParticleFieldView()
                    .allowsHitTesting(false)

                // Content column
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    // Hero logo — scales primarily from height so it doesn't collapse first
                    Image("ReveliaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: logoWidth(for: geo.size),
                            maxHeight: logoHeight(for: geo.size)
                        )
                        .layoutPriority(1)
                        .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 4)

                    Spacer().frame(height: 20)

                    // Tagline
                    Text("Think. Solve. Don't explode.")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.70), radius: 4, x: 0, y: 2)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 40)

                    // Buttons
                    VStack(spacing: 14) {

                        if hasSuspendedRun, let onResumeLastRun {
                            Button {
                                audioManager.playMenuClick()
                                onResumeLastRun()
                            } label: {
                                Text("Resume Last Run")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 220, height: 44)
                                    .background(Color(red: 0x4E / 255.0, green: 0x79 / 255.0, blue: 0x91 / 255.0))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        // Primary action — Play (no progress) or Continue (has progress)
                        Button {
                            audioManager.playMenuClick()
                            withAnimation(.easeInOut(duration: 0.08)) { primaryPressed = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                withAnimation(.easeInOut(duration: 0.08)) { primaryPressed = false }
                                onDismiss()
                            }
                        } label: {
                            Text(hasProgress ? "Continue" : "Play")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 220, height: 44)
                                .background(meadowGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(primaryPressed ? 0.97 : 1.0)

                        // How to Play
                        Button {
                            audioManager.playMenuClick()
                            showHowToPlay = true
                        } label: {
                            Text("How to Play")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 220, height: 44)
                                .background(meadowGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 32)
                }
                .frame(width: geo.size.width, height: geo.size.height)

            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) {
                Button {
                    audioManager.playMenuClick()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.95))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.55))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .padding(.top, 14)
                .padding(.trailing, 16)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    audioManager.playMenuClick()
                    onShowHighScores()
                } label: {
                    Image("HighScoreButton")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 105, height: 105)
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .help("High Scores")
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlayView()
        }
    }
}

// MARK: - Floating Particles

private struct ParticleFieldView: View {
    @State private var drift: Double = 0.0
    private let particles: [Particle] = (0..<18).map { _ in Particle() }

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                Circle()
                    .fill(Color.white.opacity(p.opacity))
                    .frame(width: p.size, height: p.size)
                    .position(
                        x: p.x * geo.size.width,
                        y: ((p.baseY - drift * p.speed + p.phaseOffset)
                               .truncatingRemainder(dividingBy: 1.0) + 1.0)
                           .truncatingRemainder(dividingBy: 1.0)
                           * geo.size.height
                    )
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 12)
                .repeatForever(autoreverses: false)
            ) {
                drift = 1.0
            }
        }
    }
}

private struct Particle: Identifiable {
    let id          = UUID()
    let x:          CGFloat
    let baseY:      Double
    let size:       CGFloat
    let opacity:    Double
    let speed:      Double
    let phaseOffset: Double

    init() {
        x           = CGFloat.random(in: 0...1)
        baseY       = Double.random(in: 0...1)
        size        = CGFloat.random(in: 2...5)
        opacity     = Double.random(in: 0.07...0.20)
        speed       = Double.random(in: 0.4...1.2)
        phaseOffset = Double.random(in: 0...1)
    }
}

// MARK: - Preview

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        TitleSplashView(onDismiss: {}, onShowHighScores: {})
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore())
            .environmentObject(SpecimenStore())
            .environmentObject(AudioManager())
            .environmentObject(LeaderboardStore())
            .frame(width: 600, height: 700)
    }
}
