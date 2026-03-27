// Signalfield/Views/WelcomeView.swift
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

    var body: some View {
        TitleSplashView(onDismiss: onComplete)
    }
}

// MARK: - TitleSplashView

/// Full-bleed title / home screen.
/// Used on every app launch and via the home button on the campaign map.
/// `onDismiss` is called when the player taps Play or Continue.
struct TitleSplashView: View {
    let onDismiss: () -> Void

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore

    // Settings sheet
    @State private var showSettings      = false
    // How to Play sheet
    @State private var showHowToPlay     = false
    // Primary button press animation
    @State private var primaryPressed    = false

    // Colour constants
    private let meadowGreen = Color(red: 0x7A / 255.0, green: 0xAA / 255.0, blue: 0x58 / 255.0)

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
                    Spacer()

                    // Hero logo — 55 % of screen width
                    Image("SignalfieldLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.55)
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

                        // Primary action — Play (no progress) or Continue (has progress)
                        Button {
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

                        // Settings
                        Button {
                            showSettings = true
                        } label: {
                            Text("Settings")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 220, height: 44)
                                .background(meadowGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        // How to Play
                        Button {
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

                    Spacer().frame(height: 48)
                }
                .frame(width: geo.size.width, height: geo.size.height)

            }
            .frame(width: geo.size.width, height: geo.size.height)
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

#Preview("Title Splash — no progress") {
    TitleSplashView(onDismiss: {})
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore())
        .frame(width: 600, height: 700)
}
