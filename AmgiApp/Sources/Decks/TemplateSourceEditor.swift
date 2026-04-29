import AmgiTheme
import SwiftUI
import UIKit

struct TemplateSourceEditor: UIViewRepresentable {
    @Binding var text: String

    let fieldNames: [String]
    let insertableTokens: [String]
    let fieldButtonTitle: String
    let doneButtonTitle: String
    let searchQuery: String
    var fontSize: Double = 14.0

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        // UIKit context: no SwiftUI environment access, fall back to system label color.
        textView.textColor = UIColor.label
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.spellCheckingType = .no
        textView.keyboardDismissMode = .interactive
        textView.text = text

        context.coordinator.attach(textView: textView)
        context.coordinator.lastValue = text
        context.coordinator.configureAccessoryView(
            fieldNames: fieldNames,
            insertableTokens: insertableTokens,
            fieldButtonTitle: fieldButtonTitle,
            doneButtonTitle: doneButtonTitle
        )
        context.coordinator.applySearch(searchQuery, in: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // CRITICAL: Update the coordinator's binding reference on every render so it always
        // points to the currently active tab's binding (front/back/css). makeCoordinator()
        // runs only once, so without this the coordinator keeps writing to the original
        // (front) binding regardless of which tab is shown.
        context.coordinator.updateBinding($text)

        // Apply font size change
        if uiView.font?.pointSize != CGFloat(fontSize) {
            uiView.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        }

        if uiView.text != text, !context.coordinator.isHandlingProgrammaticChange {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            let maxLocation = min(selectedRange.location, uiView.text.utf16.count)
            uiView.selectedRange = NSRange(location: maxLocation, length: 0)
            context.coordinator.lastValue = text
        }

        context.coordinator.attach(textView: uiView)
        context.coordinator.configureAccessoryView(
            fieldNames: fieldNames,
            insertableTokens: insertableTokens,
            fieldButtonTitle: fieldButtonTitle,
            doneButtonTitle: doneButtonTitle
        )
        context.coordinator.applySearch(searchQuery, in: uiView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        weak var textView: UITextView?
        var lastValue: String = ""
        var isHandlingProgrammaticChange = false
        private var lastSearchKey = ""

        private var lastFieldNames: [String] = []
        private var lastInsertableTokens: [String] = []
        private var lastFieldButtonTitle = ""
        private var lastDoneButtonTitle = ""

        init(text: Binding<String>) {
            self._text = text
        }

        func attach(textView: UITextView) {
            self.textView = textView
        }

        /// Called by `updateUIView` on every SwiftUI render to keep the binding
        /// pointing to the currently active tab (front / back / css).
        func updateBinding(_ binding: Binding<String>) {
            _text = binding
        }

        func textViewDidChange(_ textView: UITextView) {
            lastValue = textView.text
            text = textView.text
        }

        func applySearch(_ query: String, in textView: UITextView) {
            let key = "\(query)|\(textView.text ?? "")"
            guard key != lastSearchKey else { return }
            lastSearchKey = key

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let nsText = textView.text as NSString? ?? ""
            let range = nsText.range(of: trimmed, options: [.caseInsensitive])
            guard range.location != NSNotFound else { return }

            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
        }

        func configureAccessoryView(
            fieldNames: [String],
            insertableTokens: [String],
            fieldButtonTitle: String,
            doneButtonTitle: String
        ) {
            guard
                fieldNames != lastFieldNames
                    || insertableTokens != lastInsertableTokens
                    || fieldButtonTitle != lastFieldButtonTitle
                    || doneButtonTitle != lastDoneButtonTitle
            else {
                return
            }

            lastFieldNames = fieldNames
            lastInsertableTokens = insertableTokens
            lastFieldButtonTitle = fieldButtonTitle
            lastDoneButtonTitle = doneButtonTitle

            textView?.inputAccessoryView = makeAccessoryView(
                fieldNames: fieldNames,
                insertableTokens: insertableTokens,
                fieldButtonTitle: fieldButtonTitle,
                doneButtonTitle: doneButtonTitle
            )
            textView?.reloadInputViews()
        }

        private func makeAccessoryView(
            fieldNames: [String],
            insertableTokens: [String],
            fieldButtonTitle: String,
            doneButtonTitle: String
        ) -> UIView {
            // Outer container
            let container = UIView()
            container.backgroundColor = UIColor.secondarySystemBackground
            container.frame = CGRect(x: 0, y: 0, width: 0, height: 46)

            let topLine = UIView()
            topLine.backgroundColor = UIColor.separator
            topLine.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(topLine)

            // Scrollable left area
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            container.addSubview(scrollView)

            let stack = UIStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 2
            scrollView.addSubview(stack)

            stack.addArrangedSubview(makeIconButton(systemName: "arrow.uturn.backward") { [weak self] in
                self?.textView?.undoManager?.undo()
            })
            stack.addArrangedSubview(makeIconButton(systemName: "arrow.uturn.forward") { [weak self] in
                self?.textView?.undoManager?.redo()
            })

            if !fieldNames.isEmpty {
                stack.addArrangedSubview(makeSeparatorView())
                let fieldActions = fieldNames.map { name in
                    UIAction(title: name) { [weak self] _ in self?.insert("{{\(name)}}") }
                }
                stack.addArrangedSubview(makeMenuButton(
                    title: fieldButtonTitle,
                    menu: UIMenu(children: fieldActions)
                ))
            }

            if !insertableTokens.isEmpty {
                stack.addArrangedSubview(makeSeparatorView())
                let tokenActions = insertableTokens.map { token in
                    UIAction(title: token) { [weak self] _ in self?.insert(token) }
                }
                stack.addArrangedSubview(makeMenuButton(
                    title: "Insert",
                    menu: UIMenu(children: tokenActions)
                ))
            }

            // Done button pinned to right, outside scroll area
            let doneButton = makeDoneButton(title: doneButtonTitle) { [weak self] in
                self?.textView?.resignFirstResponder()
            }
            doneButton.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(doneButton)

            NSLayoutConstraint.activate([
                topLine.topAnchor.constraint(equalTo: container.topAnchor),
                topLine.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                topLine.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                topLine.heightAnchor.constraint(equalToConstant: 0.5),

                doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
                doneButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                scrollView.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -4),
                scrollView.topAnchor.constraint(equalTo: topLine.bottomAnchor),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            ])

            return container
        }

        private func insert(_ string: String) {
            guard let textView, let range = textView.selectedTextRange else { return }
            isHandlingProgrammaticChange = true
            textView.replace(range, withText: string)
            isHandlingProgrammaticChange = false
            textViewDidChange(textView)
        }

        private func makeIconButton(systemName: String, action: @escaping () -> Void) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            var cfg = UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: systemName)
            cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            button.configuration = cfg
            button.tintColor = UIColor.label
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return button
        }

        private func makeMenuButton(title: String, menu: UIMenu) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            var cfg = UIButton.Configuration.plain()
            cfg.attributedTitle = AttributedString(
                title,
                attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 13, weight: .regular)])
            )
            cfg.image = UIImage(systemName: "chevron.down")
            cfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 9, weight: .regular)
            cfg.imagePlacement = .trailing
            cfg.imagePadding = 3
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 6)
            button.configuration = cfg
            button.tintColor = UIColor.label
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
            return button
        }

        private func makeDoneButton(title: String, action: @escaping () -> Void) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            var cfg = UIButton.Configuration.plain()
            cfg.attributedTitle = AttributedString(
                title,
                attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 14, weight: .semibold)])
            )
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 4)
            button.configuration = cfg
            button.tintColor = UIColor.tintColor
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return button
        }

        private func makeSeparatorView() -> UIView {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = UIColor.separator
            view.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
            view.heightAnchor.constraint(equalToConstant: 20).isActive = true
            return view
        }
    }
}
