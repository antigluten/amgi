//
//  ShareSheet.swift
//  AppShared
//
//  Created by Vladimir Gusev on 09.08.2026.
//

public import SwiftUI
import UIKit

public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)?

    public init(items: [Any], onComplete: (() -> Void)? = nil) {
        self.items = items
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let onComplete {
            controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
