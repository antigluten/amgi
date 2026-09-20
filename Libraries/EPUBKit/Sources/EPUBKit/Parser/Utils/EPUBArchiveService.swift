//
//  EPUBArchiveService.swift
//  EPUBKit
//
//  Created by Witek Bobrowski on 30/06/2018.
//  Copyright © 2018 Witek Bobrowski. All rights reserved.
//

import Foundation
import ZipArchive

/// Protocol defining the interface for EPUB archive extraction operations.
///
/// This protocol abstracts the archive extraction functionality, allowing for
/// different implementations of ZIP extraction mechanisms.
protocol EPUBArchiveService {
    /// Extracts the contents of an EPUB archive to a temporary directory.
    ///
    /// - Parameter url: The file URL of the EPUB archive to extract.
    /// - Returns: The URL of the directory containing the extracted contents.
    /// - Throws: `EPUBParserError.unzipFailed` if extraction fails.
    func unarchive(archive url: URL) throws -> URL
}

/// Concrete implementation of `EPUBArchiveService` using the Zip library.
///
/// This service handles the extraction of EPUB files, which are essentially ZIP archives
/// containing structured XHTML content, metadata, and resources. According to the EPUB
/// specification (Section 3.3), an EPUB file must be a ZIP-based OCF (Open Container Format)
/// archive.
///
/// The service uses the Zip library to handle the extraction process and ensures that
/// files with the `.epub` extension are recognized as valid ZIP archives.
class EPUBArchiveServiceImplementation: EPUBArchiveService {

    /// Initializes the archive service and registers the EPUB file extension.
    ///
    /// This ensures that the Zip library recognizes `.epub` files as valid ZIP archives
    /// for extraction operations.
    init() {
    }

    /// Extracts the contents of an EPUB archive to a temporary directory.
    ///
    /// The extraction process follows these steps:
    /// 1. Validates that the file at the given URL exists
    /// 2. Uses Zip.quickUnzipFile to extract all contents to a temporary directory
    /// 3. Returns the URL of the extraction directory
    ///
    /// The temporary directory is managed by the system and will be cleaned up
    /// automatically when no longer needed.
    ///
    /// - Parameter url: The file URL of the EPUB archive to extract.
    /// - Returns: The URL of the temporary directory containing the extracted contents.
    /// - Throws: `EPUBParserError.unzipFailed` wrapping the underlying extraction error.
    /// Note Manhhao: This was updated to use ZipArchive instead. The previous Library had problems with handling permissions.
    func unarchive(archive url: URL) throws -> URL {
        let destination: URL
        let sourceDirectory = url.deletingLastPathComponent().path
        
        if FileManager.default.isWritableFile(atPath: sourceDirectory) {
            destination = url.deletingPathExtension()
        } else {
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = url.deletingPathExtension().lastPathComponent
            destination = tempDirectory.appendingPathComponent(fileName)
        }
        
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        
        let success = SSZipArchive.unzipFile(atPath: url.path, toDestination: destination.path)
        
        if success {
            return destination
        } else {
            throw EPUBParserError.unzipFailed(reason: NSError(domain: "SSZipArchive", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip file at \(url.path)"]))
        }
    }

}
