import Foundation

/// Applies a regular-expression find/replace to `input`.
///
/// On a **match**, the replaced text is the result (e.g. extract a capture group). On **no match** the
/// behaviour depends on `clearWhenNoMatch`: false (default) keeps `input` unchanged (legacy); true
/// returns the empty string — so a "copy a field then extract" rule clears the target when the pattern
/// isn't present. An empty or invalid pattern always leaves `input` unchanged (no transform).
/// The replacement template supports capture-group references ($1, $2, …) and the user escapes
/// `\n`, `\r`, `\t`, `\\` (encoded around the NSRegularExpression template engine so it doesn't consume
/// the leading backslash). Pure logic — no UI, fully unit-testable.
public func applyRegexTransform(_ input: String, pattern: String, replacement: String,
                                clearWhenNoMatch: Bool = false) -> String {
    guard !pattern.isEmpty,
          let regex = try? NSRegularExpression(pattern: pattern) else { return input }
    let range = NSRange(input.startIndex..., in: input)
    guard regex.firstMatch(in: input, range: range) != nil else {
        return clearWhenNoMatch ? "" : input
    }
    let prepared = encodeReplacementEscapes(replacement)
    let result = regex.stringByReplacingMatches(in: input, range: range, withTemplate: prepared)
    let decoded = restoreReplacementSentinels(result).trimmingCharacters(in: .whitespaces)
    // Matched: use the result. When not clearing, an empty result falls back to the original (legacy).
    if clearWhenNoMatch { return decoded }
    return decoded.isEmpty ? input : decoded
}

// Substitute user-typed escapes with sentinel chars BEFORE the NSRegularExpression
// template engine runs, so the engine doesn't consume the leading backslash.
func encodeReplacementEscapes(_ s: String) -> String {
    s.replacingOccurrences(of: "\\\\", with: "\u{0000}")
        .replacingOccurrences(of: "\\n", with: "\u{0001}")
        .replacingOccurrences(of: "\\r", with: "\u{0002}")
        .replacingOccurrences(of: "\\t", with: "\u{0003}")
}

func restoreReplacementSentinels(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{0000}", with: "\\")
        .replacingOccurrences(of: "\u{0001}", with: "\n")
        .replacingOccurrences(of: "\u{0002}", with: "\r")
        .replacingOccurrences(of: "\u{0003}", with: "\t")
}
