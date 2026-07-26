//
//  EPUBTableOfContentsParser.swift
//  EPUBKit
//
//  Created by Witek Bobrowski on 30/06/2018.
//  Copyright © 2018 Witek Bobrowski. All rights reserved.
//

import Foundation
import AEXML

/// Protocol defining the interface for parsing EPUB table of contents (NCX) elements.
///
/// The table of contents parser is responsible for extracting hierarchical navigation
/// information from NCX (Navigation Control file for XML applications) documents.
protocol EPUBTableOfContentsParser {
    /// Parses an NCX XML element into an EPUBTableOfContents object.
    ///
    /// - Parameter xmlElement: The root XML element of the NCX document.
    /// - Returns: An `EPUBTableOfContents` object containing the parsed navigation hierarchy.
    func parse(_ xmlElement: AEXMLElement) -> EPUBTableOfContents
}

/// Concrete implementation of `EPUBTableOfContentsParser` that parses NCX navigation files.
///
/// This parser extracts hierarchical navigation information from NCX (Navigation Control file
/// for XML applications) documents. NCX files are used primarily in EPUB 2 for navigation,
/// though they're still supported in EPUB 3 for backward compatibility.
///
/// Expected NCX XML structure:
/// ```xml
/// <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
///     <head>
///         <meta name="dtb:uid" content="urn:uuid:12345678-1234-1234-1234-123456789012"/>
///     </head>
///     <docTitle>
///         <text>Book Title</text>
///     </docTitle>
///     <navMap>
///         <navPoint id="chapter1" playOrder="1">
///             <navLabel>
///                 <text>Chapter 1</text>
///             </navLabel>
///             <content src="chapter1.xhtml"/>
///             <navPoint id="section1" playOrder="2">
///                 <navLabel>
///                     <text>Section 1.1</text>
///                 </navLabel>
///                 <content src="chapter1.xhtml#section1"/>
///             </navPoint>
///         </navPoint>
///     </navMap>
/// </ncx>
/// ```
///
/// The NCX specification is part of the DAISY Digital Talking Book standard and provides
/// a structured way to represent navigation hierarchies in digital publications.
class EPUBTableOfContentsParserImplementation: EPUBTableOfContentsParser {

    /// Parses the NCX XML document to extract the complete navigation hierarchy.
    ///
    /// The parsing process:
    /// 1. Extracts the document title from the `<docTitle>` element
    /// 2. Looks for the unique identifier in the `<head>` metadata
    /// 3. Recursively parses the `<navMap>` to build the navigation tree
    /// 4. Creates a root `EPUBTableOfContents` object containing all navigation points
    ///
    /// The NCX format allows for deeply nested navigation structures, where each
    /// `<navPoint>` can contain child `<navPoint>` elements to represent sub-sections,
    /// sub-chapters, or other hierarchical content organization.
    ///
    /// - Parameter xmlElement: The root XML element of the NCX document.
    /// - Returns: An `EPUBTableOfContents` object representing the complete navigation hierarchy.
    /// Note Manhhao: This was heavily restructured to support XHTML Navigation in newer .epub files
    func parse(_ xmlElement: AEXMLElement) -> EPUBTableOfContents {
        if xmlElement["navMap"].error == nil {
            return parseNCX(xmlElement)
        } else {
            return parseXHTMLNav(xmlElement)
        }
    }
    
    private func parseNCX(_ xmlElement: AEXMLElement) -> EPUBTableOfContents {
        // STEP 1: Extract the unique identifier from NCX head metadata
        // The dtb:uid meta element should match the dc:identifier in the package document
        // This provides a consistency check between the NCX and OPF files
        // POTENTIAL BUG: The attribute name appears to have a typo - "dtb=uid" should be "dtb:uid"
        // This may cause identifier extraction to fail for properly formatted NCX files
        let item = xmlElement["head"]["meta"]
            .all(withAttributes: ["name": "dtb=uid"])?
            .first?
            .attributes["content"]
        
        // STEP 2: Create the root table of contents object
        // The NCX docTitle provides the overall publication title for navigation
        // This may differ from the dc:title in metadata if a shorter form is desired
        var tableOfContents = EPUBTableOfContents(
            label: xmlElement["docTitle"]["text"].value ?? "",
            id: "0", // Root level uses a synthetic ID since NCX root has no id attribute
            item: item, // Reference to the unique identifier for cross-document validation
            subTable: [] // Will be populated recursively with the navigation hierarchy
        )
        
        // STEP 3: Recursively parse the navigation map to build the complete hierarchy
        // The navMap contains the root-level navPoints, each of which may contain
        // nested navPoints creating a tree structure for complex documents
        tableOfContents.subTable = evaluateChildren(from: xmlElement["navMap"])
        
        return tableOfContents

    }
    
    /// Parses XHTML
    ///
    /// Expected XHTML structure:
    /// ```xml
    /// <nav epub:type="toc">
    ///   <ol>
    ///     <li><a href="chapter1.xhtml">Chapter 1</a></li>
    ///     <li><a href="chapter2.xhtml">Chapter 2</a>
    ///       <ol>
    ///         <li><a href="chapter2.xhtml#sec1">Section 2.1</a></li>
    ///       </ol>
    ///     </li>
    ///   </ol>
    /// </nav>
    /// ```
    private func parseXHTMLNav(_ xmlElement: AEXMLElement) -> EPUBTableOfContents {
        var tableOfContents = EPUBTableOfContents(
            label: "",
            id: "0",
            item: nil,
            subTable: []
        )
        
        if let nav = findTocNav(in: xmlElement) {
            tableOfContents.subTable = parseOL(nav["ol"])
        }
        
        return tableOfContents
    }
    
    private func findTocNav(in element: AEXMLElement) -> AEXMLElement? {
        if element.name == "nav" {
            if let type = element.attributes["epub:type"], type.contains("toc") {
                return element
            }
        }
        
        for child in element.children {
            if let found = findTocNav(in: child) {
                return found
            }
        }
        
        return nil
    }
    
    private func parseOL(_ ol: AEXMLElement) -> [EPUBTableOfContents] {
        guard let items = ol["li"].all else { return [] }
        
        return items.compactMap { li -> EPUBTableOfContents? in
            let a = li["a"]
            guard a.error == nil else { return nil }
            
            let label = a.value ?? "Unknown"
            let href = a.attributes["href"]
            
            let nestedOL = li["ol"]
            let children: [EPUBTableOfContents]? = nestedOL.error == nil ? parseOL(nestedOL) : nil
            
            return EPUBTableOfContents(
                label: label,
                id: UUID().uuidString,
                item: href,
                subTable: children
            )
        }
    }

}

extension EPUBTableOfContentsParserImplementation {

    /// Recursively evaluates navigation points to build the hierarchical table of contents.
    ///
    /// This method processes `<navPoint>` elements within the NCX document, extracting:
    /// - Navigation labels (display text for the table of contents)
    /// - Content sources (file paths or URLs to the actual content)
    /// - Unique identifiers for each navigation point
    /// - Nested navigation points for sub-sections
    ///
    /// The recursive nature allows for unlimited nesting depth, supporting complex
    /// document structures with multiple levels of organization (parts, chapters,
    /// sections, subsections, etc.).
    ///
    /// Each navPoint structure in NCX:
    /// ```xml
    /// <navPoint id="unique-id" playOrder="sequence-number">
    ///     <navLabel>
    ///         <text>Display Text</text>
    ///     </navLabel>
    ///     <content src="path/to/content.xhtml#optional-fragment"/>
    ///     <!-- Optional nested navPoints -->
    /// </navPoint>
    /// ```
    ///
    /// - Parameter xmlElement: The XML element containing navPoint children (navMap or navPoint).
    /// - Returns: An array of `EPUBTableOfContents` objects representing the navigation hierarchy.
    /// Note Manhhao: Forced unwrapping here caused crashing with XHTML
    private func evaluateChildren(from xmlElement: AEXMLElement) -> [EPUBTableOfContents] {
        // STEP 1: Get all navPoint elements from the current level
        // Return empty array if no navPoints exist (base case for recursion)
        guard let points = xmlElement["navPoint"].all else { return [] }
        
        // STEP 2: Process each navPoint to create table of contents entries
        // This mapping operation transforms XML navPoint elements into our domain model
        let subs: [EPUBTableOfContents] = points.map { point in
            EPUBTableOfContents(
                // Extract the display label from navLabel/text
                // This is the text that will be shown in the table of contents UI
                // Fallback to empty string for malformed NCX files
                label: point["navLabel"]["text"].value ?? "",
                
                // Extract the unique ID attribute (required by NCX specification)
                // Force unwrap is safe here because valid NCX files must have IDs
                // Invalid NCX files should fail fast rather than continue with corrupted data
                id: point.attributes["id"] ?? UUID().uuidString,
                
                // Extract the content source from the content element
                // This href points to the actual XHTML content file, potentially with a fragment identifier
                // The src attribute is required by NCX spec, so force unwrap is appropriate
                item: point["content"].attributes["src"] ?? "",
                
                // RECURSIVE STEP: Process any nested navPoints
                // This is the core of the recursive algorithm - each navPoint can contain
                // child navPoints, creating unlimited nesting depth for complex documents
                // The recursion naturally handles the tree traversal and construction
                subTable: evaluateChildren(from: point)
            )
        }
        
        return subs
    }

}
