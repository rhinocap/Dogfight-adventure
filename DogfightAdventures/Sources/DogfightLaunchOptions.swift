//
//  DogfightLaunchOptions.swift
//  Dogfight Adventures
//

import Foundation

enum DogfightMultiplayerMode: Equatable {
    case solo
    case host
    case joinNearby
}

struct DogfightLaunchOptions: Equatable {
    let mode: DogfightMultiplayerMode

    var autoStarts: Bool {
        mode != .solo
    }

    static let solo = DogfightLaunchOptions(mode: .solo)

    static func fromProcessArguments(_ arguments: [String] = CommandLine.arguments) -> DogfightLaunchOptions {
        if arguments.contains("--autostart-host") {
            return DogfightLaunchOptions(mode: .host)
        }
        if arguments.contains("--autostart-join-nearby") {
            return DogfightLaunchOptions(mode: .joinNearby)
        }
        return .solo
    }
}
