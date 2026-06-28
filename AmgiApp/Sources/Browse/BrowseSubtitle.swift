import Foundation

func composeNoteSubtitle(notetypeName: String?, tags: String) -> String? {
    let trimmed = tags.trimmingCharacters(in: .whitespaces)
    switch (notetypeName, trimmed.isEmpty) {
    case (let name?, false): return "\(name) · \(trimmed)"
    case (let name?, true):  return name
    case (nil, false):       return trimmed
    case (nil, true):        return nil
    }
}
