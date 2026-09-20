//
//  Rating.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 27.03.2026.
//

public enum Rating: Int16, Sendable, CaseIterable, Comparable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    public static func < (lhs: Rating, rhs: Rating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
