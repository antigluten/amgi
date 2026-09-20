//
//  LookupExtractionScript.swift
//  Reader
//
//  Created by Vladimir Gusev on 12.09.2026.
//

import Foundation

public enum LookupExtractionScript {
    public static let source: String = {
        guard let url = Bundle.module.url(forResource: "LookupExtraction", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("LookupExtraction.js missing from the Reader resource bundle")
            return ""
        }
        return source
    }()
}
