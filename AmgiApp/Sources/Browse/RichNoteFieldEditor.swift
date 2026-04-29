import SwiftUI
import UIKit

/// A note field editor that defaults to plain-text editing and can preserve raw
/// HTML source for fields that contain embedded media.
///
/// Anki stores field values as HTML fragments. This editor strips HTML tags for
/// display/editing and writes back plain text on change. This avoids the crash-
/// prone `NSAttributedString` HTML parsing path.
struct RichNoteFieldEditor: UIViewRepresentable {
    @Binding var htmlText: String
    var preservesSourceHTML = false

    static func normalizedStoredHTML(_ text: String) -> String {
        Coordinator.normalizedStoredHTML(from: text)
    }

    private let doneButtonTitle = "Done"
    private let boldTitle = "Bold"
    private let italicTitle = "Italic"
    private let underlineTitle = "Underline"
    private let strikeTitle = "Strikethrough"
    private let clearFormatTitle = "Clear formatting"

    func makeCoordinator() -> Coordinator {
        Coordinator(htmlText: $htmlText)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.layer.cornerRadius = 0
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = .label
        context.coordinator.attach(textView: textView)
        textView.inputAccessoryView = makeInputToolbar(for: textView, coordinator: context.coordinator)

        textView.text = displayText(for: htmlText)
        context.coordinator.lastRenderedValue = htmlText
        context.coordinator.lastPlainText = textView.text ?? ""
        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(max(32, fit.height), 160)
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        guard !context.coordinator.isEditing else { return }
        guard htmlText != context.coordinator.lastRenderedValue else { return }

        let displayedText = displayText(for: htmlText)
        if uiView.text != displayedText {
            let selected = uiView.selectedRange
            uiView.text = displayedText
            let maxLoc = max(0, min(selected.location, displayedText.utf16.count))
            uiView.selectedRange = NSRange(location: maxLoc, length: 0)
        }
        context.coordinator.lastRenderedValue = htmlText
        context.coordinator.lastPlainText = displayedText
    }

    private func displayText(for html: String) -> String {
        let normalized = Coordinator.normalizedStoredHTML(from: html)
        return preservesSourceHTML ? normalized : Coordinator.plainText(from: normalized)
    }

    // MARK: - Toolbar

    private func makeInputToolbar(for textView: UITextView, coordinator: Coordinator) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        container.backgroundColor = .secondarySystemBackground

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = .separator
        container.addSubview(divider)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        container.addSubview(scrollView)

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(
            makeSymbolButton(systemName: "arrow.uturn.backward") {
                textView.undoManager?.undo()
            }
        )
        stackView.addArrangedSubview(
            makeSymbolButton(systemName: "arrow.uturn.forward") {
                textView.undoManager?.redo()
            }
        )

        stackView.addArrangedSubview(
            makeFormatButton(systemName: "bold", title: boldTitle) {
                coordinator.wrapSelection(prefix: "<b>", suffix: "</b>")
            }
        )
        stackView.addArrangedSubview(
            makeFormatButton(systemName: "italic", title: italicTitle) {
                coordinator.wrapSelection(prefix: "<i>", suffix: "</i>")
            }
        )
        stackView.addArrangedSubview(
            makeFormatButton(systemName: "underline", title: underlineTitle) {
                coordinator.wrapSelection(prefix: "<u>", suffix: "</u>")
            }
        )
        stackView.addArrangedSubview(
            makeFormatButton(systemName: "strikethrough", title: strikeTitle) {
                coordinator.wrapSelection(prefix: "<s>", suffix: "</s>")
            }
        )
        stackView.addArrangedSubview(
            makeFormatButton(systemName: "textformat", title: clearFormatTitle) {
                coordinator.clearFormattingInSelection()
            }
        )

        stackView.addArrangedSubview(
            makeTextButton(title: doneButtonTitle) {
                textView.resignFirstResponder()
            }
        )

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -6),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -12),
        ])

        return container
    }

    private func makeSymbolButton(systemName: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 8
        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .small
        configuration.baseBackgroundColor = .tertiarySystemFill
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        button.configuration = configuration
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeFormatButton(systemName: String, title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 8
        button.accessibilityLabel = title
        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .small
        configuration.baseBackgroundColor = .tertiarySystemFill
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        button.configuration = configuration
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeTextButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.titleLabel?.numberOfLines = 1
        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .small
        configuration.baseBackgroundColor = .tertiarySystemFill
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        button.configuration = configuration
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var htmlText: String
        weak var textView: UITextView?
        var lastRenderedValue: String = ""
        var lastPlainText: String = ""
        var isEditing = false

        init(htmlText: Binding<String>) {
            self._htmlText = htmlText
        }

        func attach(textView: UITextView) {
            self.textView = textView
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            commit(textView.text ?? "")
        }

        func textViewDidChange(_ textView: UITextView) {
            commit(textView.text ?? "")
        }

        private func commit(_ plain: String) {
            let normalized = Self.normalizedStoredHTML(from: plain)
            lastPlainText = plain
            lastRenderedValue = normalized
            htmlText = normalized
        }

        func insert(_ string: String) {
            guard let textView, let range = textView.selectedTextRange else { return }
            textView.replace(range, withText: string)
            commit(textView.text ?? "")
        }

        func wrapSelection(prefix: String, suffix: String) {
            guard let textView else { return }
            let selected = textView.selectedRange
            let original = textView.text ?? ""
            let source = original as NSString
            let selectedText = source.substring(with: selected)
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            let updated = source.replacingCharacters(in: selected, with: replacement)
            textView.text = updated

            if selected.length == 0 {
                let cursor = selected.location + (prefix as NSString).length
                textView.selectedRange = NSRange(location: cursor, length: 0)
            } else {
                let rangeStart = selected.location + (prefix as NSString).length
                textView.selectedRange = NSRange(location: rangeStart, length: selected.length)
            }

            commit(updated)
        }

        func clearFormattingInSelection() {
            guard let textView else { return }
            let selected = textView.selectedRange
            let original = textView.text ?? ""
            let source = original as NSString

            let targetRange: NSRange
            if selected.length > 0 {
                targetRange = selected
            } else {
                targetRange = NSRange(location: 0, length: source.length)
            }

            let target = source.substring(with: targetRange)
            let cleaned = Self.removeInlineHTMLFormatting(from: target)
            let updated = source.replacingCharacters(in: targetRange, with: cleaned)
            textView.text = updated

            let cursor = targetRange.location + (cleaned as NSString).length
            textView.selectedRange = NSRange(location: cursor, length: 0)
            commit(updated)
        }

        // MARK: - HTML strip

        /// Strips HTML tags and decodes common entities to produce editable plain text.
        static func plainText(from html: String) -> String {
            guard !html.isEmpty else { return "" }
            guard isLikelyHTML(html) else { return html }

            var result = ""
            result.reserveCapacity(html.count)
            var inTag = false
            for ch in html.unicodeScalars {
                switch ch {
                case "<": inTag = true
                case ">": inTag = false
                default:
                    if !inTag { result.unicodeScalars.append(ch) }
                }
            }

            result = result
                .replacingOccurrences(of: "&amp;",  with: "&")
                .replacingOccurrences(of: "&lt;",   with: "<")
                .replacingOccurrences(of: "&gt;",   with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;",  with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")

            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static func normalizedStoredHTML(from text: String) -> String {
            guard text.localizedCaseInsensitiveContains("anki-mathjax") else { return text }
            let pattern = #"<anki-mathjax(?:[^>]*?block=\"(.*?)\")?[^>]*?>(.*?)</anki-mathjax>"#
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                return text
            }

            let source = text as NSString
            var output = ""
            var currentLocation = 0

            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                let fullRange = match.range(at: 0)
                output += source.substring(with: NSRange(location: currentLocation, length: fullRange.location - currentLocation))

                let blockValue: String? = {
                    let range = match.range(at: 1)
                    guard range.location != NSNotFound else { return nil }
                    return source.substring(with: range)
                }()

                let innerText: String = {
                    let range = match.range(at: 2)
                    guard range.location != NSNotFound else { return "" }
                    return source.substring(with: range)
                }()

                let trimmed = trimMathJaxBreaks(in: innerText)
                if let blockValue, !blockValue.isEmpty, blockValue.caseInsensitiveCompare("false") != .orderedSame {
                    output += #"\["# + trimmed + #"\]"#
                } else {
                    output += #"\("# + trimmed + #"\)"#
                }

                currentLocation = fullRange.location + fullRange.length
            }

            output += source.substring(from: currentLocation)
            return output
        }

        private static func isLikelyHTML(_ text: String) -> Bool {
            text.contains("<") && text.contains(">")
        }

        private static func trimMathJaxBreaks(in text: String) -> String {
            text
                .replacingOccurrences(
                    of: #"<br[ ]*/?>"#,
                    with: "\n",
                    options: [.regularExpression, .caseInsensitive]
                )
                .replacingOccurrences(of: #"^\n*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\n*$"#, with: "", options: .regularExpression)
        }

        private static func removeInlineHTMLFormatting(from text: String) -> String {
            var output = text
            let patterns = [
                "(?i)</?(b|strong|i|em|u|s|strike|del)>",
                "(?i)</?font[^>]*>",
                "(?i)</?span[^>]*>"
            ]
            for pattern in patterns {
                output = output.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: .regularExpression
                )
            }
            return output
        }
    }
}
