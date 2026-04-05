// Revelia/Audio/AudioAssets.swift
//
// Central inventory of selected audio filenames expected by the app.
//
// The manifest in selected_audio_manifest.csv is the source of truth for
// these resource names. AudioManager resolves files by bundle resource name,
// so the filenames below must match the bundled assets exactly.

import Foundation

enum AudioAssets {

    static let placementInstructions =
        "Add the manifest-selected audio files to the Revelia target as bundle resources."

    enum Music {
        static let home = "music_home.mp3"
        static let biomeMap = "music_biome_map.mp3"
        // Biome map and level select intentionally share one looping track so
        // audio can continue seamlessly when drilling into a biome.
        static let levelSelect = biomeMap
        static let victory = "music_victory.mp3"
        static let loss = "music_loss.mp3"

        static func gameplay(for biomeId: Int) -> String {
            switch biomeId % 9 {
            case 0: return "music_training_range.mp3"
            case 1: return "music_fog_marsh.mp3"
            case 2: return "music_bioluminescence.mp3"
            case 3: return "music_frozen_mirrors.mp3"
            case 4: return "music_ruins.mp3"
            case 5: return "music_the_underside.mp3"
            case 6: return "music_coral_basin.mp3"
            case 7: return "music_quicksand.mp3"
            default: return "music_the_delta.mp3"
            }
        }

        static var inventory: [String] {
            [
                home,
                biomeMap,
                levelSelect,
                "music_training_range.mp3",
                "music_fog_marsh.mp3",
                "music_bioluminescence.mp3",
                "music_frozen_mirrors.mp3",
                "music_ruins.mp3",
                "music_the_underside.mp3",
                "music_coral_basin.mp3",
                "music_quicksand.mp3",
                "music_the_delta.mp3",
                victory,
                loss,
            ]
        }
    }

    enum SFX {
        static let menuClick = "ui_button_tap.mp3"
        static let menuBack = "ui_button_back.mp3"
        static let openSettings = "ui_open_settings.mp3"
        static let closeSheet = "ui_close_sheet.mp3"
        static let toggleOn = "ui_toggle_on.mp3"
        static let toggleOff = "ui_toggle_off.mp3"
        static let safeScan = "sfx_scan_safe.mp3"
        static let safeScanBig = "sfx_scan_safe_big.mp3"
        static let cascade = "sfx_cascade_wash.mp3"
        static let hazardLoss = "sfx_hazard_loss.mp3"
        static let tagPlace = "sfx_tag_place.mp3"
        static let tagRemove = "sfx_tag_remove.mp3"
        static let tagCycleSuspect = "sfx_tag_cycle_suspect.mp3"
        static let tagCycleConfirmed = "sfx_tag_cycle_confirmed.mp3"
        static let chord = "sfx_chord.mp3"
        static let invalidAction = "sfx_invalid_action.mp3"
        static let win = "sfx_win_stinger.mp3"
        static let lossTrigger = "sfx_loss_trigger.mp3"
        static let scoreCountupTick = "sfx_score_countup_tick.mp3"
        static let starAward = "sfx_star_award.mp3"
        static let beaconTarget = "sfx_fog_beacon_ping.mp3"
        static let beaconClear = "sfx_fog_reveal.mp3"
        static let conductorTarget = "sfx_conductor_pulse.mp3"
        static let conductorPulse = "sfx_conductor_pulse.mp3"
        static let linkedTilePing = "sfx_linked_tile_ping.mp3"
        static let lockedTileUnlock = "sfx_locked_tile_unlock.mp3"
        static let invertedSignalReveal = "sfx_inverted_signal_reveal.mp3"
        static let sonarToggle = "sfx_sonar_pulse.mp3"
        static let fadingSignalSink = "sfx_fading_signal_sink.mp3"
        static let fadingSignalResurface = "sfx_fading_signal_resurface.mp3"
        static let casualShieldTrigger = "sfx_casual_shield_trigger.mp3"
        static let biomeUnlockBanner = "sfx_biome_unlock_banner.mp3"
        static let mapPinAppear = "sfx_map_pin_appear.mp3"
        static let levelStart = "sfx_level_start.mp3"
        static let pauseOpen = "sfx_pause_open.mp3"
        static let pauseClose = "sfx_pause_close.mp3"

        static let inventory: [String] = [
            menuClick,
            menuBack,
            openSettings,
            closeSheet,
            toggleOn,
            toggleOff,
            safeScan,
            safeScanBig,
            cascade,
            hazardLoss,
            tagPlace,
            tagRemove,
            tagCycleSuspect,
            tagCycleConfirmed,
            chord,
            invalidAction,
            win,
            lossTrigger,
            scoreCountupTick,
            starAward,
            beaconTarget,
            beaconClear,
            conductorTarget,
            conductorPulse,
            linkedTilePing,
            lockedTileUnlock,
            invertedSignalReveal,
            sonarToggle,
            fadingSignalSink,
            fadingSignalResurface,
            casualShieldTrigger,
            biomeUnlockBanner,
            mapPinAppear,
            levelStart,
            pauseOpen,
            pauseClose,
        ]
    }
}
