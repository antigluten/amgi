//
//  CardWebViewConfig.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 01.05.2026.
//

import Foundation

enum CardWebViewReplayMode: String, Sendable {
    case question
    case answerOnly
    case answerWithQuestion
}

package enum CardWebViewContentAlignment: String, Sendable {
    case top
    case center
}
