//
//  ReviewAudioSession.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 04.05.2026.
//

import AVFoundation
import Foundation

@MainActor
enum ReviewAudioSession {
    static func apply(playInSilent: Bool) {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = playInSilent ? .playback : .ambient
        do {
            try session.setCategory(category, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // Audio category failures are non-fatal — a card whose audio cannot
            // play due to category mismatch will still render correctly.
        }
        #endif
    }

    static func release() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        #endif
    }
}
