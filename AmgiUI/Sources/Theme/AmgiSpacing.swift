//
//  AmgiSpacing.swift
//  Theme
//
//  Created by Vladimir Gusev on 20.07.2026.
//

public import CoreGraphics

/// Central spacing tokens for the Minimal design language.
/// Design-language values, shared by every theme — not palette slots.
public enum AmgiSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    /// `AmgiCard`'s default content inset — off the main scale by design
    /// (card breathing room reads better slightly looser than `xl`), named
    /// so it isn't a bare magic number at the shared card primitive.
    public static let cardInset: CGFloat = 20
}
