//
//  ImageOcclusionFitTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import CoreGraphics
import Testing
import UIKit
@testable import BrowseFeature

@Suite("Image occlusion fit")
struct ImageOcclusionFitTests {
    private let cap = AddImageOcclusionModel.maxImageEdge

    @Test func leavesImagesInsideTheCapAlone() {
        let small = CGSize(width: 800, height: 600)
        #expect(AddImageOcclusionModel.imageFit(for: small) == small)

        let exact = CGSize(width: cap, height: cap / 2)
        #expect(AddImageOcclusionModel.imageFit(for: exact) == exact)
    }

    @Test func capsTheLongestEdgeAndKeepsTheAspectRatio() {
        for size in [CGSize(width: 4032, height: 3024), CGSize(width: 3024, height: 4032)] {
            let fitted = AddImageOcclusionModel.imageFit(for: size)

            #expect(max(fitted.width, fitted.height) == cap)
            #expect(
                abs(fitted.width / fitted.height - size.width / size.height) < 0.0001,
                "aspect ratio drifted: \(size) → \(fitted)"
            )
        }
    }

    @Test func zeroSizeDoesNotDivideByZero() {
        #expect(AddImageOcclusionModel.imageFit(for: .zero) == .zero)
    }

    @Test func storedJPEGIsTheFittedCopy() async throws {
        let original = Self.solidImage(CGSize(width: 4032, height: 3024))
        #expect(max(original.size.width, original.size.height) == 4032)

        let (fitted, data) = await AddImageOcclusionModel.fittedForStorage(original)
        let jpeg = try #require(data)
        let decoded = try #require(UIImage(data: jpeg))

        #expect(max(fitted.size.width, fitted.size.height) <= cap)
        #expect(
            max(decoded.size.width, decoded.size.height) <= cap,
            "the written file is \(decoded.size), over the \(cap) cap"
        )

        let unfitted = try #require(original.jpegData(compressionQuality: 0.92))
        #expect(jpeg.count < unfitted.count, "the stored copy should be smaller than the original encode")
    }

    @Test func aSmallImageIsStoredAsIs() async throws {
        let small = Self.solidImage(CGSize(width: 640, height: 480))
        let (fitted, data) = await AddImageOcclusionModel.fittedForStorage(small)

        #expect(fitted.size == small.size)
        let jpeg = try #require(data)
        let decoded = try #require(UIImage(data: jpeg))
        #expect(decoded.size == small.size)
    }

    private static func solidImage(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            for x in stride(from: 0.0, to: size.width, by: 40) {
                context.fill(CGRect(x: x, y: 0, width: 12, height: size.height))
            }
        }
    }
}
