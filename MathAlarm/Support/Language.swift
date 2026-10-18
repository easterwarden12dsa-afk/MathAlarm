import SwiftUI

/// The app's language. Hebrew switches the layout to right-to-left and
/// translates every visible string through `L(_:)`; math stays left-to-right.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en", hebrew = "he"

    var id: String { rawValue }
    var title: String { self == .hebrew ? "עברית" : "English" }

    /// Read from any thread (Text initialisers); written only from Settings.
    nonisolated(unsafe) static var current: AppLanguage = {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"), let l = AppLanguage(rawValue: saved) { return l }
        return Locale.preferredLanguages.first?.hasPrefix("he") == true ? .hebrew : .english
    }()

    var locale: Locale { Locale(identifier: self == .hebrew ? "he_IL" : "en") }
    var direction: LayoutDirection { self == .hebrew ? .rightToLeft : .leftToRight }
}

/// Translates a visible string into the current language (English strings pass through).
func L(_ s: String) -> String {
    guard AppLanguage.current == .hebrew else { return s }
    return HebrewTranslator.shared.translate(s)
}

/// English → Hebrew from Resources/hebrew.json (built by tools/hebrew_build.py):
/// exact strings, templates with values filled in ("Problem {} of {}"),
/// and phrases for text built from pieces. Math is kept left-to-right.
final class HebrewTranslator: @unchecked Sendable {
    static let shared = HebrewTranslator()

    private struct Template {
        let regex: NSRegularExpression
        let firstLiteral: String
        /// Hebrew pieces: text, or the index of an English value.
        let pieces: [Piece]
    }
    private enum Piece { case text(String), value(Int) }

    private var exact: [String: String] = [:]
    private var templates: [Template] = []
    private var phrases: [(String, String)] = []
    private var cache: [String: String] = [:]
    private let lock = NSLock()

    private init() {
        guard let url = Bundle.main.url(forResource: "hebrew", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        exact = json["exact"] as? [String: String] ?? [:]
        for pair in json["templates"] as? [[String]] ?? [] where pair.count == 2 {
            if let t = Self.compile(pair[0], pair[1]) { templates.append(t) }
        }
        phrases = (json["phrases"] as? [[String]] ?? []).compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
    }

    private static func compile(_ en: String, _ he: String) -> Template? {
        let parts = en.components(separatedBy: "{}")
        // A value never runs across a sentence end (". " before a capital), so long texts split cleanly.
        let hole = #"((?:(?![.?!] [A-Z"“(]).)*?)"#
        let pattern = "^" + parts.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: hole) + "$"
        guard let rx = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        // Hebrew pieces: "{}" takes the next value, "{2}" a given one.
        var pieces: [Piece] = []
        var next = 0
        var rest = Substring(he)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            let inside = rest[rest.index(after: open)..<close]
            if inside.isEmpty || Int(inside) != nil {
                if open > rest.startIndex { pieces.append(.text(String(rest[..<open]))) }
                if let n = Int(inside) { pieces.append(.value(n - 1)) } else { pieces.append(.value(next)); next += 1 }
                rest = rest[rest.index(after: close)...]
            } else {
                pieces.append(.text(String(rest[...close])))
                rest = rest[rest.index(after: close)...]
            }
        }
        if !rest.isEmpty { pieces.append(.text(String(rest))) }
        let first = parts.max { $0.count < $1.count } ?? ""
        return Template(regex: rx, firstLiteral: first, pieces: pieces)
    }

    func translate(_ s: String) -> String {
        guard s.range(of: "[A-Za-z]{2,}", options: .regularExpression) != nil else { return s }
        lock.lock()
        if let hit = cache[s] { lock.unlock(); return hit }
        lock.unlock()
        let out = Self.bidi(translateRaw(s, depth: 0))
        lock.lock(); cache[s] = out; lock.unlock()
        return out
    }

    /// Exact, template or nothing.
    private func direct(_ s: String, depth: Int) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let e = exact[s] ?? exact[trimmed] { return e }
        guard depth < 4 else { return nil }
        let ns = trimmed as NSString
        for t in templates where t.firstLiteral.isEmpty || trimmed.contains(t.firstLiteral) {
            guard let m = t.regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) else { continue }
            var values: [String] = []
            for i in 1..<m.numberOfRanges {
                let r = m.range(at: i)
                values.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            var out = ""
            for p in t.pieces {
                switch p {
                case .text(let x): out += x
                case .value(let i): if i < values.count { out += translateRaw(values[i], depth: depth + 1) }
                }
            }
            return out
        }
        return nil
    }

    private func translateRaw(_ s: String, depth: Int) -> String {
        guard s.range(of: "[A-Za-z]{2,}", options: .regularExpression) != nil else { return s }
        if let d = direct(s, depth: depth) { return d }
        // Text made of several sentences: translate the longest runs of sentences that match.
        let sentences = Self.sentences(s)
        if sentences.count > 1 {
            var out: [String] = []
            var i = 0
            while i < sentences.count {
                var matched = false
                for j in stride(from: sentences.count, to: i, by: -1) where !(i == 0 && j == sentences.count) {
                    let chunk = sentences[i..<j].joined(separator: " ")
                    if let d = direct(chunk, depth: depth) { out.append(d); i = j; matched = true; break }
                }
                if !matched { out.append(phrased(sentences[i])); i += 1 }
            }
            return out.joined(separator: " ")
        }
        // Clauses joined by a dash or an arrow: translate each one.
        if depth < 4 {
            for sep in [" — ", ";  ", "  →  "] where s.contains(sep) {
                return s.components(separatedBy: sep).map { translateRaw($0, depth: depth + 1) }.joined(separator: sep)
            }
        }
        return phrased(s)
    }

    /// Replaces known phrases inside a longer text (whole words only).
    private func phrased(_ s: String) -> String {
        var out = s
        for (en, he) in phrases where out.contains(en) {
            out = Self.replaceWords(out, en, he)
        }
        return out
    }

    private static func replaceWords(_ s: String, _ en: String, _ he: String) -> String {
        var result = ""
        var rest = s[...]
        while let r = rest.range(of: en) {
            let before = r.lowerBound > rest.startIndex ? rest[rest.index(before: r.lowerBound)] : " "
            let after = r.upperBound < rest.endIndex ? rest[r.upperBound] : " "
            let enStartsWord = en.first?.isLetter == true, enEndsWord = en.last?.isLetter == true
            if (enStartsWord && before.isLetter) || (enEndsWord && after.isLetter) {
                result += rest[..<r.upperBound]
            } else {
                result += rest[..<r.lowerBound] + he
            }
            rest = rest[r.upperBound...]
        }
        return result + rest
    }

    /// Splits after ". ", "? " or "! " when the next sentence starts with a capital, a quote or a bracket.
    private static func sentences(_ s: String) -> [String] {
        let chars = Array(s)
        var out: [String] = [], current = ""
        var i = 0
        while i < chars.count {
            current.append(chars[i])
            if ".?!".contains(chars[i]), i + 2 < chars.count, chars[i + 1] == " ",
               chars[i + 2].isUppercase || "\"“(".contains(chars[i + 2]) {
                out.append(current)
                current = ""
                i += 2
                continue
            }
            i += 1
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    // MARK: Right-to-left with math inside

    private static func isHebrew(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x0590...0x05FF).contains($0.value) }
    }

    /// Hebrew text with math inside: every math run is isolated so it reads
    /// left to right, and the paragraph starts right-to-left.
    static func bidi(_ s: String) -> String {
        guard s.contains(where: isHebrew) else { return s }
        var out = "\u{200F}"
        var run = ""
        func flush() {
            guard !run.isEmpty else { return }
            // Keep spaces, punctuation and a joining hyphen outside the isolate.
            let edge: Set<Character> = [" ", ",", ".", ":", ";", "?", "!", "-", "״", "׳", "\u{200F}"]
            var lead = "", core = Substring(run), trail = ""
            while let c = core.first, edge.contains(c) { lead.append(c); core = core.dropFirst() }
            while let c = core.last, edge.contains(c) || c == ")" && !core.contains("(") { trail = String(c) + trail; core = core.dropLast() }
            if core.contains(where: { $0.isLetter || $0.isNumber || "∞√π∫=<>≤≥+−×÷′″^²³".contains($0) }) {
                out += lead + "\u{2066}" + String(core) + "\u{2069}" + trail
            } else {
                out += run
            }
            run = ""
        }
        for c in s {
            if isHebrew(c) || c == "\u{200F}" {
                flush()
                if c != "\u{200F}" { out.append(c) }
            } else {
                run.append(c)
            }
        }
        flush()
        return out
    }
}

// MARK: - Every visible string goes through L()

extension Text {
    /// Plain strings (variables, literals, interpolations) are translated.
    init(_ string: String) {
        self.init(verbatim: L(string))
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: String, systemImage: String) {
        self.init { Text(title) } icon: { Image(systemName: systemImage) }
    }
}

extension Button where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action) { Text(title) }
    }

    init(_ title: String, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

extension Toggle where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}

extension Picker where Label == Text {
    init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(title) }
    }
}

extension Section where Parent == Text, Content: View, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(title) }
    }
}

extension LabeledContent where Label == Text, Content == Text {
    init(_ title: String, value: String) {
        self.init { Text(value) } label: { Text(title) }
    }
}

extension View {
    func navigationTitle(_ title: String) -> some View {
        navigationTitle(Text(title))
    }

    /// Math, graphs and the keypad always read left to right.
    func mathDirection() -> some View {
        environment(\.layoutDirection, .leftToRight)
    }

    /// The app's language and reading direction.
    func appLanguage(_ language: AppLanguage) -> some View {
        environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.direction)
    }
}
