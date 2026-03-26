// Signalfield/ViewModels/GameViewModel.swift

import Foundation
import SwiftUI
import Combine

// MARK: - Game State

/// The state machine for a game session.
enum GameState: Equatable {
    case notStarted
    case waitingForFirstScan   // Board created, hazards NOT placed yet
    case playing
    case paused
    case won
    case exploding             // Hazard hit — board revealed, shatter animation playing
    case lost
}

// MARK: - Game ViewModel

/// Manages the full lifecycle of a single game session.
/// Owns the board, timer, stats, and all player actions.
@MainActor
class GameViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var board: Board
    @Published private(set) var gameState: GameState = .notStarted
    @Published private(set) var stats: RunStats = RunStats()
    @Published private(set) var score: Int = 0
    @Published private(set) var stars: Int = 0
    @Published private(set) var elapsedTime: Double = 0

    // MARK: - Beacon Charges (Biome 1: Fog Marsh)

    /// Remaining beacon charges the player can use to clear fog on individual tiles.
    @Published private(set) var beaconChargesRemaining: Int = 0

    /// When true, the next scan-click targets a fogged tile to clear its fog
    /// instead of performing a normal scan.
    @Published private(set) var isBeaconTargeting: Bool = false

    // MARK: - Conductor Charges (Biome 2: Bioluminescence)

    /// Remaining conductor charges the player can use to illuminate a 3×3 area.
    @Published private(set) var conductorChargesRemaining: Int = 0

    /// When true, the next scan-click will illuminate the 3×3 area around that tile
    /// for 1 second, revealing the true state of all tiles in the zone.
    @Published private(set) var isConductorTargeting: Bool = false

    /// The set of tile coordinates currently illuminated by a conductor flash.
    /// Populated for 1 second after a conductor charge is used, then cleared.
    @Published private(set) var illuminatedCoords: Set<Coordinate> = []

    /// In-flight Task that clears `illuminatedCoords` after the 1-second flash.
    private var illuminationTask: Task<Void, Never>?

    // MARK: - Linked Tile Highlight (Biome 3: Frozen Mirrors)

    /// The coordinate that should be highlighted to show a link connection.
    /// Set for 1.5 s when a linked tile is revealed, pointing to the partner.
    /// Also written directly by GameView when hover drives the highlight.
    @Published var linkedHighlightedCoord: Coordinate? = nil

    // MARK: - Sonar Lock (Biome 6: Coral Basin / Biome 8: The Delta)

    /// The set of revealed sonar tile coordinates whose sight lines are pinned on.
    /// Toggled by left-clicking a revealed sonar tile with no active targeting mode.
    @Published var lockedSonarCoords: Set<Coordinate> = []

    // MARK: - Explosion (Hazard Hit Animation)

    /// The coordinate of the hazard tile that triggered the loss.
    /// Set when `gameState` transitions to `.exploding`; cleared on retry/reset.
    /// GameView uses this as the epicentre of the chain-reaction shatter.
    @Published private(set) var explosionOrigin: Coordinate? = nil

    // MARK: - Quicksand Fade (Biome 7: Quicksand)

    /// Fade progress for the entire board: 0.0 = fully visible, 1.0 = fully faded.
    /// TileView maps this to opacity via `1 − progress` (pure linear fade)
    /// and overlays a sand tint at `progress × 0.22` opacity.
    @Published private(set) var quicksandFadeProgress: Double = 0.0

    // MARK: - Configuration

    let levelSpec: LevelSpec
    private(set) var seed: UInt64

    // MARK: - Timers

    private var timerCancellable: AnyCancellable?

    /// 30 fps countdown timer that drives quicksandFadeProgress toward 1.0.
    private var quicksandTimerCancellable: AnyCancellable?

    /// The Date at which the current countdown started (or where it was adjusted
    /// to resume from a paused state). Nil when no countdown is running.
    private var quicksandFadeStartDate: Date?

    /// In-flight Task for the resurface animation delay. Cancelled whenever a new
    /// resurface is triggered, so rapid clicks don't stack multiple restarts.
    private var quicksandResurfaceTask: Task<Void, Never>?

    // MARK: - Scripted Board Flag

    /// True when this session uses the pre-built tutorial board for L1.
    /// When true, `handleFirstScan` skips `BoardGenerator.placeHazards` because
    /// the board already has hazards and signals pre-computed.
    private(set) var isScriptedBoard: Bool = false

    // MARK: - Initialization

    /// Create a new game session.
    ///
    /// - Parameters:
    ///   - levelSpec: The level to play.
    ///   - seed: An explicit seed for debugging/seed-sharing. When nil (the default),
    ///     a truly random seed is generated via `BoardGenerator.generateSeed()`.
    ///   - useScriptedBoard: When true and levelSpec.id == "L1", loads the hardcoded
    ///     tutorial board instead of generating a random one. Used for the guided
    ///     tutorial on first play; all subsequent L1 plays use random boards.
    init(levelSpec: LevelSpec, seed: UInt64? = nil, useScriptedBoard: Bool = false) {
        self.levelSpec = levelSpec
        self.seed = seed ?? BoardGenerator.generateSeed()

        if useScriptedBoard && levelSpec.id == "L1" {
            self.board = TutorialBoard.makeBoard()
            self.isScriptedBoard = true
        } else {
            self.board = BoardGenerator.createEmptyBoard(for: levelSpec, seed: self.seed)
            self.isScriptedBoard = false
        }

        self.stats.seed = self.seed
        self.beaconChargesRemaining = levelSpec.beaconCharges ?? 0
        self.conductorChargesRemaining = levelSpec.conductorCharges ?? 0
        self.gameState = .waitingForFirstScan
    }

    // MARK: - Player Actions

    /// Scan (reveal) a tile. Left-click action.
    func scanTile(at coord: Coordinate) {
        guard board.isValid(coord) else { return }

        switch gameState {
        case .waitingForFirstScan:
            handleFirstScan(at: coord)
        case .playing:
            handleScan(at: coord)
        default:
            return  // No scanning in other states
        }
    }

    /// Tag a tile. Right-click / ctrl-click action.
    /// Cycles: none → suspect → confirmed → none.
    func tagTile(at coord: Coordinate) {
        // Tags are only meaningful once hazards have been placed (first scan done).
        // Allowing .waitingForFirstScan caused an instant-win bug: before the first
        // scan the board has zero hazards, so checkWinCondition() saw 0/0 hazards
        // confirmed and triggered an immediate win on any right-click or two-finger tap.
        guard gameState == .playing else { return }
        guard board.isValid(coord) else { return }

        let tile = board[coord]
        guard tile.isHidden else { return }   // Can only tag hidden tiles
        guard !tile.isLocked else { return }  // Locked tiles are always safe — no tagging

        switch tile.tagState {
        case .none:
            board[coord].tagState = .suspect
        case .suspect:
            board[coord].tagState = .confirmed
            // Track incorrect confirmed flags (only meaningful after hazards are placed).
            // Placing a confirmed tag on a non-hazard tile disqualifies the run from ★★/★★★.
            // Removing the flag later does NOT undo this — the mistake is permanent.
            if gameState == .playing && !tile.isHazard {
                stats.incorrectFlagsEverPlaced += 1
            }
        case .confirmed:
            board[coord].tagState = .none
        }

        stats.tagsPlacedCount += 1

        // A confirmed tag on a hazard counts toward neighboring locked tile thresholds
        // (Biome 4: Ruins). Recalculate immediately so countdowns update in real time,
        // both when a correct flag is placed and when it is removed.
        processLockedTileUpdates()

        checkWinCondition()
    }

    /// Chord a tile. Shift-click action.
    /// If the revealed tile's signal equals its adjacent confirmed tag count,
    /// auto-reveal all other adjacent hidden tiles.
    func chordTile(at coord: Coordinate) {
        guard gameState == .playing else { return }
        guard board.isValid(coord) else { return }

        let tile = board[coord]
        guard tile.isRevealed, let signal = tile.signal else { return }

        // Can't chord a fogged tile — the player doesn't know the exact signal
        if tile.hasFog { return }

        let neighbors = board.neighbors(of: coord)
        let confirmedCount = neighbors.count(where: { board[$0].hasConfirmedTag })

        // Only chord if confirmed tags == signal count
        guard confirmedCount == signal else { return }

        // Reveal all non-tagged, non-locked hidden neighbors
        // Locked tiles (Biome 4) cannot be chord-revealed — they have their own unlock mechanic.
        let toReveal = neighbors.filter { board[$0].isHidden && !board[$0].hasConfirmedTag && !board[$0].isLocked }

        for neighbor in toReveal {
            if board[neighbor].isHazard {
                // Chord into a hazard — game over (tags were wrong)
                board[neighbor].state = .exploded
                handleLoss()
                return
            }
            revealTile(at: neighbor)
        }

        processLockedTileUpdates()
        // Biome 7: a chord reveals hidden tiles — resurface numbers + reset countdown
        if levelSpec.hasQuicksand && !toReveal.isEmpty { resurfaceAndRestartCountdown() }
        checkWinCondition()
    }

    /// Toggle the sight-line lock for a revealed sonar tile.
    ///
    /// First click pins the sight lines on; second click unpins them.
    /// Only valid on revealed sonar tiles; silently ignored otherwise.
    func toggleSonarLock(at coord: Coordinate) {
        guard board.isValid(coord) else { return }
        guard board[coord].isSonar && board[coord].isRevealed else { return }
        if lockedSonarCoords.contains(coord) {
            lockedSonarCoords.remove(coord)
        } else {
            lockedSonarCoords.insert(coord)
        }
    }

    /// Pause the game.
    func pause() {
        guard gameState == .playing else { return }
        gameState = .paused
        stopTimer()
        // Cancel any active illumination flash — the board is blurred while paused anyway.
        illuminationTask?.cancel()
        illuminationTask = nil
        illuminatedCoords = []
        isConductorTargeting = false
        if levelSpec.hasQuicksand { pauseQuicksandCountdown() }
    }

    /// Resume from pause.
    func resume() {
        guard gameState == .paused else { return }
        gameState = .playing
        startTimer()
        if levelSpec.hasQuicksand { resumeQuicksandCountdown() }
    }

    /// Retry the current level with a fresh random seed.
    /// Every retry generates a unique board — no same-seed replays.
    func retry() {
        resetGame(seed: BoardGenerator.generateSeed())
    }

    // MARK: - First Scan Handling

    private func handleFirstScan(at coord: Coordinate) {
        // Locked tiles are completely inert while locked — the first scan must
        // land on a normal (non-locked) tile. Return early so the game stays
        // in .waitingForFirstScan and the player must click elsewhere.
        guard !board[coord].isLocked else { return }

        if isScriptedBoard {
            // Tutorial board: hazards and signals are already pre-populated.
            // Skip BoardGenerator.placeHazards — the board is ready to play.
        } else {
            // Normal play: place hazards now that we know the safe zone.
            board = BoardGenerator.placeHazards(
                on: board,
                firstScan: coord,
                spec: levelSpec,
                seed: seed
            )
        }

        // Transition to playing
        gameState = .playing
        startTimer()
        if levelSpec.hasQuicksand { startQuicksandCountdown() }

        // Reveal the first-scanned tile
        revealTile(at: coord)
        stats.scansCount += 1

        processLockedTileUpdates()
        checkWinCondition()
    }

    // MARK: - Scan Handling

    private func handleScan(at coord: Coordinate) {
        let tile = board[coord]

        // Can't scan revealed or confirmed-tagged tiles
        guard tile.isHidden else { return }
        if tile.hasConfirmedTag { return }

        // Can't directly scan locked tiles — they unlock via neighbor reveals (Biome 4)
        if tile.isLocked { return }

        stats.scansCount += 1

        if tile.isHazard {
            // Hit a hazard — game over
            board[coord].state = .exploded
            handleLoss()
            return
        }

        revealTile(at: coord)
        processLockedTileUpdates()
        // Biome 7: scanning a hidden tile resurfaces all numbers + resets countdown
        if levelSpec.hasQuicksand { resurfaceAndRestartCountdown() }
        checkWinCondition()
    }

    /// Reveal a single tile and trigger cascade if signal is 0.
    private func revealTile(at coord: Coordinate) {
        board[coord].state = .revealed
        board[coord].tagState = .none  // Clear tags on reveal

        // Biome 3: when a linked tile is revealed, briefly highlight its partner
        // so the player sees the connection. The highlight clears after 1.5 s.
        if let partnerCoord = board[coord].linkedData?.partnerCoord {
            linkedHighlightedCoord = partnerCoord
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                // Only clear if this reveal is still the active highlight
                if self?.linkedHighlightedCoord == partnerCoord {
                    self?.linkedHighlightedCoord = nil
                }
            }
        }

        // Cascade from 0-signal tiles (non-fogged, or fog-cleared)
        if let signal = board[coord].signal, signal == 0, !board[coord].hasFog {
            let _ = CascadeEngine.cascade(from: coord, on: &board)
        }
    }

    // MARK: - Beacon Charges (Fog Clearing)

    /// Enter beacon targeting mode. The next scan-click on a fogged tile
    /// will spend a charge and clear that tile's fog.
    func activateBeacon() {
        guard gameState == .playing else { return }
        guard beaconChargesRemaining > 0 else { return }
        isBeaconTargeting = true
    }

    /// Cancel beacon targeting mode without spending a charge.
    func cancelBeaconTargeting() {
        isBeaconTargeting = false
    }

    /// Spend a beacon charge to clear fog on a specific tile.
    /// Called when the player clicks a fogged tile while in targeting mode.
    /// Returns true if the charge was used successfully.
    @discardableResult
    func useBeaconCharge(at coord: Coordinate) -> Bool {
        guard isBeaconTargeting else { return false }
        guard beaconChargesRemaining > 0 else { return false }
        guard board.isValid(coord) else { return false }

        let tile = board[coord]

        // Can only target revealed fogged tiles (tiles that show a range)
        // OR hidden fogged tiles that the player wants to pre-clear
        guard tile.hasFog else {
            // Not a fogged tile — cancel targeting, don't spend charge
            return false
        }

        // Clear the fog
        RuleEngine.clearFog(at: coord, on: &board)
        beaconChargesRemaining -= 1
        isBeaconTargeting = false
        stats.chargesUsed = true   // Spending a charge disqualifies from ★★★

        // If the tile is already revealed and now has signal 0, trigger cascade
        if tile.isRevealed, let signal = board[coord].signal, signal == 0 {
            let _ = CascadeEngine.cascade(from: coord, on: &board)
        }

        processLockedTileUpdates()
        checkWinCondition()
        return true
    }

    // MARK: - Conductor Charges (Bioluminescence Flash)

    /// Enter conductor targeting mode. The next scan-click illuminates a 3×3 area.
    func activateConductor() {
        guard gameState == .playing else { return }
        guard conductorChargesRemaining > 0 else { return }
        isConductorTargeting = true
    }

    /// Cancel conductor targeting mode without spending a charge.
    func cancelConductorTargeting() {
        isConductorTargeting = false
    }

    /// Spend a conductor charge to illuminate the 3×3 area around the given tile.
    /// Called when the player clicks any tile while in targeting mode.
    /// The flash lasts exactly 1 second, then fades out over 0.3 s.
    /// Returns true if the charge was used successfully.
    @discardableResult
    func useConductorCharge(at coord: Coordinate) -> Bool {
        guard isConductorTargeting else { return false }
        guard conductorChargesRemaining > 0 else { return false }
        guard board.isValid(coord) else { return false }

        // Build the illumination zone centered on the clicked tile
        // (3×3 for square boards = center + 8 neighbors; center + 6 for hex boards)
        var zone = Set<Coordinate>()
        zone.insert(coord)
        for neighbor in board.neighbors(of: coord) {
            zone.insert(neighbor)
        }

        conductorChargesRemaining -= 1
        isConductorTargeting = false
        stats.chargesUsed = true   // Spending a charge disqualifies from ★★★

        // Cancel any previous illumination that's still in flight
        illuminationTask?.cancel()

        // Light up the zone immediately
        illuminatedCoords = zone

        // Schedule the flash to clear after 1 second
        illuminationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.0))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.illuminatedCoords = []
            }
        }

        return true
    }

    // MARK: - Win/Loss Checking

    private func checkWinCondition() {
        // Win condition 1: All safe tiles are revealed
        let allSafeRevealed = board.revealedSafeCount == board.safeTileCount

        // Win condition 2: All hazards have confirmed tags AND no incorrect confirmed tags
        let allHazardsTagged = board.confirmedHazardCount == board.hazardCount
            && board.incorrectConfirmedTagCount == 0

        if allSafeRevealed || allHazardsTagged {
            handleWin()
        }
    }

    private func handleWin() {
        gameState = .won
        stopTimer()
        stopQuicksandTimer()
        illuminationTask?.cancel()
        illuminationTask = nil
        illuminatedCoords = []
        stats.elapsedTimeSeconds = elapsedTime
        stats.confirmedTagsCount = board.count(where: { $0.hasConfirmedTag })
        score = ScoringCalculator.calculateScore(stats: stats)
        stars = ScoringCalculator.calculateStars(
            stats: stats,
            parTimeSeconds: levelSpec.parTimeSeconds
        )
    }

    private func handleLoss() {
        // Store the exploded tile coordinate before state transition.
        // There is always exactly one .exploded tile set by handleScan/chordTile.
        explosionOrigin = board.allCoordinates.first { board[$0].state == .exploded }

        gameState = .exploding
        stopTimer()
        stopQuicksandTimer()
        illuminationTask?.cancel()
        illuminationTask = nil
        illuminatedCoords = []
        stats.elapsedTimeSeconds = elapsedTime

        // Reveal the entire board so the player can study it during the
        // ~2 second pause before the shatter animation begins.
        revealEntireBoard()
    }

    /// Called by the explosion animation when it finishes.
    /// Transitions from `.exploding` → `.lost` so the loss card appears.
    func completeExplosion() {
        guard gameState == .exploding else { return }
        gameState = .lost
    }

    /// On loss, reveal all tiles to show the full board state.
    private func revealEntireBoard() {
        for coord in board.allCoordinates {
            if board[coord].isHidden {
                // Clear any locked state so the post-game board shows
                // clean signals without stale lock/countdown overlays.
                board[coord].lockedData = nil
                board[coord].state = .revealed
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedTime += 0.1
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Locked Tile Management (Biome 4: Ruins)

    /// Update all locked tiles' remaining neighbor counts and unlock any that have
    /// met their threshold. Repeats until no more unlocks happen to handle chains:
    /// an unlocked tile with signal 0 cascades, revealing more neighbors, potentially
    /// unlocking more locked tiles, and so on.
    ///
    /// Call after any action that reveals tiles OR changes tag state on neighboring tiles.
    ///
    /// A locked tile's countdown tracks the combined total of:
    ///   - Revealed (safe) neighbor tiles
    ///   - Correctly confirmed-tagged hazard neighbor tiles
    ///
    /// An incorrect confirmed tag on a non-hazard tile does NOT count.
    /// This ensures every locked tile is solvable even when surrounded by hazards.
    private func processLockedTileUpdates() {
        guard levelSpec.hasLocked else { return }

        var anyUnlocked = true
        while anyUnlocked {
            anyUnlocked = false

            for coord in board.allCoordinates {
                guard let lockedData = board[coord].lockedData else { continue }

                // Count neighbors that contribute to the unlock threshold:
                // revealed tiles + correctly confirmed-tagged hazard tiles.
                // An incorrect flag (confirmed tag on a safe tile) is excluded.
                // Uses board.neighbors(of:) so hex boards use 6-neighbor topology.
                let neighbors = board.neighbors(of: coord)
                let unlockedCount = neighbors.count(where: {
                    board[$0].isRevealed ||
                    (board[$0].isHazard && board[$0].hasConfirmedTag)
                })
                let remaining = max(0, lockedData.unlockThreshold - unlockedCount)

                // Update the countdown display on the HUD/tile
                board[coord].lockedData?.remainingNeighborsNeeded = remaining

                // Unlock if threshold reached
                if remaining == 0 {
                    board[coord].lockedData = nil
                    board[coord].state = .revealed
                    board[coord].tagState = .none
                    anyUnlocked = true

                    // Cascade from the newly unlocked tile if its signal is 0
                    if let signal = board[coord].signal, signal == 0, !board[coord].hasFog {
                        let _ = CascadeEngine.cascade(from: coord, on: &board)
                    }
                }
            }
        }
    }

    // MARK: - Quicksand Countdown (Biome 7)

    /// Start (or restart) the 30 fps countdown from the current `quicksandFadeProgress`.
    ///
    /// Uses a Date-based approach to avoid floating-point accumulation: the start
    /// date is shifted back by `progress × duration` so that the computed
    /// `elapsed / duration` immediately equals the current progress on the first tick.
    /// This makes pause/resume seamless — just call `startQuicksandCountdown()` again
    /// after updating `quicksandFadeProgress` to wherever the pause left off.
    private func startQuicksandCountdown() {
        guard levelSpec.hasQuicksand else { return }
        let duration = levelSpec.quicksandFadeSeconds
        // Shift the start date back by however much progress has already elapsed,
        // so the timer picks up exactly where it left off.
        quicksandFadeStartDate = Date().addingTimeInterval(
            -quicksandFadeProgress * duration
        )
        quicksandTimerCancellable = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let startDate = self.quicksandFadeStartDate else { return }
                let elapsed = Date().timeIntervalSince(startDate)
                self.quicksandFadeProgress = min(1.0, elapsed / self.levelSpec.quicksandFadeSeconds)
            }
    }

    /// Stop the countdown timer and clear the start-date bookmark.
    /// Called on pause, win, loss, and reset. Does NOT reset `quicksandFadeProgress`
    /// so the visual state is preserved during pause (and can be resumed from there).
    private func stopQuicksandTimer() {
        quicksandResurfaceTask?.cancel()
        quicksandResurfaceTask = nil
        quicksandTimerCancellable?.cancel()
        quicksandTimerCancellable = nil
        quicksandFadeStartDate = nil
    }

    /// Resurface all revealed numbers (animate progress → 0) and restart the countdown.
    ///
    /// Called whenever the player scans or chords a hidden tile. The resurface
    /// animation (ease-out, 0.25 s) is allowed to play out before the timer starts,
    /// giving the player the full fade window from the moment numbers are fully visible.
    ///
    /// Rapid taps cancel any in-flight resurface Task so only one restart is scheduled.
    func resurfaceAndRestartCountdown() {
        guard levelSpec.hasQuicksand else { return }
        // Cancel any pending Task from a previous resurface so we don't double-restart.
        quicksandResurfaceTask?.cancel()
        // Stop the current countdown so no timer tick overwrites the animation.
        stopQuicksandTimer()
        // Snap progress to 0 visually (SwiftUI animates from current value to 0).
        withAnimation(.easeOut(duration: 0.25)) {
            quicksandFadeProgress = 0.0
        }
        // After the animation completes, restart the countdown from zero.
        quicksandResurfaceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.25))
            guard let self, !Task.isCancelled, self.gameState == .playing else { return }
            self.startQuicksandCountdown()
        }
    }

    /// Record the current progress and stop the timer (called on pause).
    /// `quicksandFadeProgress` is left unchanged so the board stays at its current
    /// fade level while paused.
    private func pauseQuicksandCountdown() {
        stopQuicksandTimer()  // stopQuicksandTimer already nils quicksandFadeStartDate
    }

    /// Resume the countdown from wherever it paused (called on resume).
    /// `startQuicksandCountdown` uses the current `quicksandFadeProgress` to
    /// reconstruct the correct start date, so the window continues seamlessly.
    private func resumeQuicksandCountdown() {
        startQuicksandCountdown()
    }

    // MARK: - Reset

    private func resetGame(seed: UInt64) {
        stopTimer()
        stopQuicksandTimer()
        illuminationTask?.cancel()
        illuminationTask = nil
        quicksandFadeProgress = 0.0
        self.seed = seed
        self.board = BoardGenerator.createEmptyBoard(for: levelSpec, seed: seed)
        self.gameState = .waitingForFirstScan
        self.stats = RunStats()
        self.stats.seed = seed
        self.score = 0
        self.stars = 0
        self.elapsedTime = 0
        self.beaconChargesRemaining = levelSpec.beaconCharges ?? 0
        self.isBeaconTargeting = false
        self.conductorChargesRemaining = levelSpec.conductorCharges ?? 0
        self.isConductorTargeting = false
        self.illuminatedCoords = []
        self.linkedHighlightedCoord = nil
        self.explosionOrigin = nil
        self.lockedSonarCoords = []
    }
}
