# Third-Party Notices

This directory vendors third-party code under the MIT License.

## EPUBKit

- Copyright (c) 2022 Witek Bobrowski
- Upstream: https://github.com/witekbobrowski/EPUBKit
- License: MIT (see `LICENSE` in this directory)

EPUBKit transitively depends on:

## AEXML

- Copyright (c) Marko Tadić
- Upstream: https://github.com/tadija/AEXML
- License: MIT

## ZipArchive (SSZipArchive)

- Copyright (c) ZipArchive contributors
- Upstream: https://github.com/ZipArchive/ZipArchive
- License: MIT

AEXML and ZipArchive are SwiftPM dependencies, resolved from upstream and unmodified. The vendored EPUBKit is a modified fork taken from Manhhao's Hoshi-Reader (https://github.com/Manhhao/Hoshi-Reader, `Libraries/EPUBKit` at commit 874767b0; changes marked "Note Manhhao" in the sources). It uses ZipArchive instead of marmelroy/Zip, extracts next to the source file when that location is writable and reuses an existing extraction, adds EPUB3 XHTML navigation and NCX-less spine support, hardens the NCX parser against missing attributes, and raises the platform minimums to macOS 10.15 (required by ZipArchive 2.6.0) and iOS/tvOS 16. Amgi further dropped the upstream test target and raised iOS/tvOS to 17, which AEXML ≥ 4.7.2 requires.
