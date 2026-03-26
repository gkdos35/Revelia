// Signalfield/Tutorial/TutorialManager.swift
//
// Manages the step-by-step L1 guided tutorial and biome intro tooltip state.
//
// TutorialManager is created by GameView (when running L1 for the first time)
// and passed down to TutorialOverlayView. It publishes the current step so
// the overlay can react automatically, and receives board input events so it can
// decide whether to advance or ignore them.
//
// Lifecycle:
//   1. RootView creates a TutorialManager when the Tutorial button is tapped.
//   2. GameView receives it as an optional property.
//   3. When isActive, GameView routes ALL board input through handleBoardInput(_:action:).
//   4. On step completion, TutorialManager publishes the next step.
//   5. On tutorial completion (step 9 auto-dismiss), onComplete closure is called
//      so SettingsStore can persist hasCompletedL1Tutorial = true.

import Combine
import Foundation
import SwiftUI

// MARK: - Tutorial Step

/// Each step in the L1 guided tutorial. Cases map 1:1 to the spec.
enum TutorialStep: Equatable {
    case inactive       // Tutorial not running (normal play)
    case step1_goal     // Welcome — no spotlight, full dim, "Got it" button
    case step2_firstScan // Spotlight (2,2) — wait for left-click on that tile
    case step3_cascade   // Spotlight (1,1) — blank tile explanation, "Got it"
    case step4_signalOne // Spotlight (3,1) — "1" signal with neighbor highlight, "Got it"
    case step5_signalTwo // Spotlight (4,2) — "2" signal with neighbor highlight, "Got it"
    case step6_deduction // Spotlight (3,2) — deduction moment with highlight, "Got it"
    case step7_tagHazard // Spotlight (4,1) — wait for right-click (tag) on that tile
    case step8_revealSafe // Spotlight (4,0) — wait for left-click on that tile
    case step9_release   // No spotlight, release message, auto-dismiss 3s
    case complete        // Tutorial done, manager inactive
}

// MARK: - Tutorial Manager

/// Controls the L1 guided tutorial step sequence.
///
/// **Thread safety:** @MainActor — all mutations happen on the main thread.
@MainActor
final class TutorialManager: ObservableObject {

    // MARK: Published State

    @Published private(set) var currentStep: TutorialStep = .inactive

    // MARK: Callbacks

    /// Called when the tutorial completes (step 9 finishes).
    /// Use this to write `hasCompletedL1Tutorial = true` in SettingsStore.
    var onComplete: (() -> Void)?

    /// Called when the tutorial wants to forward a scan action to the game engine.
    /// The String parameter is unused; Coordinate is the target.
    var onForwardScan: ((Coordinate) -> Void)?

    /// Called when the tutorial wants to forward a tag action to the game engine.
    var onForwardTag: ((Coordinate) -> Void)?

    // MARK: - Derived State

    /// True while the tutorial is active and should overlay the game board.
    var isActive: Bool {
        currentStep != .inactive && currentStep != .complete
    }

    /// The board coordinate to spotlight (cutout hole in scrim). Nil = no spotlight.
    var spotlightCoord: Coordinate? {
        switch currentStep {
        case .step2_firstScan: return TutorialBoard.firstScanCoord
        case .step3_cascade:   return TutorialBoard.zeroCascadeCoord
        case .step4_signalOne: return TutorialBoard.signalOneCoord
        case .step5_signalTwo: return TutorialBoard.signalTwoCoord
        case .step6_deduction: return TutorialBoard.deductionCoord
        case .step7_tagHazard: return TutorialBoard.hazardCoord
        case .step8_revealSafe: return TutorialBoard.safeTileCoord
        default: return nil
        }
    }

    /// The board coordinates to draw the amber neighbor-highlight ring around.
    /// Empty = no highlight.
    var highlightCoords: [Coordinate] {
        switch currentStep {
        case .step4_signalOne:
            // All 8 neighbors of (3,1) on the 6×6 board
            return boardNeighbors(of: TutorialBoard.signalOneCoord)
        case .step5_signalTwo:
            // All 8 neighbors of (4,2)
            return boardNeighbors(of: TutorialBoard.signalTwoCoord)
        case .step6_deduction:
            // All 8 neighbors of (3,2)
            return boardNeighbors(of: TutorialBoard.deductionCoord)
        default:
            return []
        }
    }

    /// The tooltip message for the current step.
    var tooltipText: String {
        switch currentStep {
        case .step1_goal:
            return "Welcome to Signalfield! Your goal: reveal every safe tile. But beware — hazards are hidden in the field."
        case .step2_firstScan:
            return "Click this tile to scan it."
        case .step3_cascade:
            return "A blank tile means no hazards nearby. Its neighbors are revealed automatically."
        case .step4_signalOne:
            return "This 1 means exactly one of these highlighted tiles hides a hazard."
        case .step5_signalTwo:
            return "A 2 means two hazards among these tiles. Higher numbers, more danger."
        case .step6_deduction:
            return "Look — this 1 has only one hidden neighbor left. That tile MUST be the hazard!"
        case .step7_tagHazard:
            return "Right-click to tag it as a hazard."
        case .step8_revealSafe:
            return "The hazard is tagged. This tile must be safe — scan it!"
        case .step9_release:
            return "You've got the basics. Reveal all safe tiles to win. Good luck!"
        default:
            return ""
        }
    }

    /// True when the current step advances via a "Got it" button tap (not board input).
    var requiresGotItButton: Bool {
        switch currentStep {
        case .step1_goal, .step3_cascade, .step4_signalOne,
             .step5_signalTwo, .step6_deduction, .step9_release:
            return true
        default:
            return false
        }
    }

    // MARK: - Start

    /// Begin the tutorial from step 1. Call this when L1 loads in tutorial mode.
    func start() {
        currentStep = .step1_goal
    }

    // MARK: - Advance

    /// Advance to the next step. Called by the overlay's "Got it" button or
    /// internally after a board action completes a step.
    func advance() {
        switch currentStep {
        case .step1_goal:       currentStep = .step2_firstScan
        case .step2_firstScan:  currentStep = .step3_cascade
        case .step3_cascade:    currentStep = .step4_signalOne
        case .step4_signalOne:  currentStep = .step5_signalTwo
        case .step5_signalTwo:  currentStep = .step6_deduction
        case .step6_deduction:  currentStep = .step7_tagHazard
        case .step7_tagHazard:  currentStep = .step8_revealSafe
        case .step8_revealSafe: currentStep = .step9_release
        case .step9_release:
            currentStep = .complete
            onComplete?()
        default:
            break
        }
    }

    // MARK: - Board Input Routing

    /// Called by GameView for every board input while the tutorial is active.
    ///
    /// - If the action matches the expected step input (e.g. left-click on the
    ///   spotlighted tile), the action is forwarded to the game engine AND the
    ///   step advances.
    /// - All other inputs are silently swallowed.
    func handleBoardInput(_ action: BoardInputAction) {
        switch currentStep {

        case .step2_firstScan:
            // Waiting for left-click on (2,2)
            if case .scan(let coord) = action, coord == TutorialBoard.firstScanCoord {
                onForwardScan?(coord)
                advance()   // Move to step 3 (cascade explanation)
            }

        case .step7_tagHazard:
            // Waiting for right-click on (4,1)
            if case .tag(let coord) = action, coord == TutorialBoard.hazardCoord {
                onForwardTag?(coord)
                advance()   // Move to step 8
            }

        case .step8_revealSafe:
            // Waiting for left-click on (4,0)
            if case .scan(let coord) = action, coord == TutorialBoard.safeTileCoord {
                onForwardScan?(coord)
                advance()   // Move to step 9
            }

        default:
            // All other inputs are blocked during guided steps.
            break
        }
    }

    // MARK: - Step 9 Auto-Dismiss

    /// Start the 3-second auto-dismiss timer for step 9 (release message).
    /// Call this when the step9_release overlay appears.
    func scheduleStep9AutoDismiss() {
        guard currentStep == .step9_release else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if currentStep == .step9_release {
                advance()
            }
        }
    }

    // MARK: - Helpers

    /// Returns all valid 8-neighbors of a coordinate on the 6×6 tutorial board.
    private func boardNeighbors(of coord: Coordinate) -> [Coordinate] {
        var result: [Coordinate] = []
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = coord.row + dr
                let nc = coord.col + dc
                if nr >= 0 && nr < 6 && nc >= 0 && nc < 6 {
                    result.append(Coordinate(row: nr, col: nc))
                }
            }
        }
        return result
    }
}
