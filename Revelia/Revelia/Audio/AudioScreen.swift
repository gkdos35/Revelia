// Revelia/Audio/AudioScreen.swift

import Foundation

enum AudioScreen: Equatable {
    case home
    case biomeMap
    case levelSelect(biomeId: Int)
    case gameplay(biomeId: Int)
    case victory(biomeId: Int)
    case loss(biomeId: Int)

    var musicFileName: String {
        switch self {
        case .home:
            return AudioAssets.Music.home
        case .biomeMap:
            return AudioAssets.Music.biomeMap
        case .levelSelect:
            return AudioAssets.Music.levelSelect
        case .gameplay(let biomeId):
            return AudioAssets.Music.gameplay(for: biomeId)
        case .victory:
            return AudioAssets.Music.victory
        case .loss:
            return AudioAssets.Music.loss
        }
    }
}
