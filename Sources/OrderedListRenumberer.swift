import Foundation

/// Plans the smallest marker-only edits needed to keep one affected ordered-list
/// block continuous. The editor applies the edits; this type knows nothing about
/// AppKit, undo managers, bindings, or styling.
enum OrderedListRenumberer {
    struct Replacement: Equatable {
        let range: NSRange
        let text: String
    }

    private struct Item {
        let lineRange: NSRange
        let numberRange: NSRange
        let rawNumber: String
        let components: [Int]
    }

    static let lineExpression = try! NSRegularExpression(
        pattern: "^([ \\t]*)((?:\\d+\\.)*\\d+)([.)])([ \\t]*)(.*)$")

    static func replacements(in text: String, affectedRange: NSRange) -> [Replacement] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let probe = expandedProbe(affectedRange, length: ns.length)
        let searchRange = localSearchRange(in: ns, around: probe)
        var out: [Replacement] = []

        for block in blocks(in: ns, range: searchRange) where intersects(block, probe: probe) {
            var counters = block[0].components
            for item in block.dropFirst() {
                let depth = item.components.count
                if depth > counters.count {
                    while counters.count < depth { counters.append(1) }
                } else {
                    counters = Array(counters.prefix(depth))
                    counters[depth - 1] += 1
                }
                let expected = counters.map(String.init).joined(separator: ".")
                if item.rawNumber != expected {
                    out.append(Replacement(range: item.numberRange, text: expected))
                }
            }
        }
        return out.sorted { $0.range.location < $1.range.location }
    }

    static func adjustedSelection(_ selection: NSRange,
                                  for replacements: [Replacement]) -> NSRange {
        let sorted = replacements.sorted { $0.range.location < $1.range.location }
        let start = adjustedPosition(selection.location, for: sorted)
        let end = adjustedPosition(NSMaxRange(selection), for: sorted)
        return NSRange(location: start, length: max(0, end - start))
    }

    private static func adjustedPosition(_ position: Int,
                                         for replacements: [Replacement]) -> Int {
        var result = position
        var cumulativeDelta = 0
        for replacement in replacements {
            let newLength = (replacement.text as NSString).length
            let delta = newLength - replacement.range.length
            if position >= NSMaxRange(replacement.range) {
                result += delta
                cumulativeDelta += delta
            } else if position > replacement.range.location {
                let offset = position - replacement.range.location
                return replacement.range.location + cumulativeDelta + min(offset, newLength)
            } else {
                break
            }
        }
        return result
    }

    private static func blocks(in text: NSString, range: NSRange) -> [[Item]] {
        var blocks: [[Item]] = []
        var current: [Item] = []
        var location = range.location
        let limit = NSMaxRange(range)

        while location < limit {
            var start = 0
            var end = 0
            var contentsEnd = 0
            text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd,
                              for: NSRange(location: location, length: 0))
            let lineRange = NSRange(location: start, length: contentsEnd - start)
            let line = text.substring(with: lineRange)
            if let item = parse(line, at: lineRange) {
                current.append(item)
            } else if !current.isEmpty {
                blocks.append(current)
                current = []
            }
            guard end > location else { break }
            location = end
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks
    }

    private static func parse(_ line: String, at lineRange: NSRange) -> Item? {
        let ns = line as NSString
        let whole = NSRange(location: 0, length: ns.length)
        guard let match = lineExpression.firstMatch(in: line, range: whole) else { return nil }
        let raw = ns.substring(with: match.range(at: 2))
        let parts = raw.split(separator: ".")
        let components = parts.compactMap { Int($0) }
        guard !components.isEmpty, components.count == parts.count else { return nil }
        let localNumber = match.range(at: 2)
        return Item(
            lineRange: lineRange,
            numberRange: NSRange(location: lineRange.location + localNumber.location,
                                 length: localNumber.length),
            rawNumber: raw,
            components: components)
    }

    private static func expandedProbe(_ affected: NSRange, length: Int) -> NSRange {
        let start = min(max(0, affected.location), length)
        let end = min(max(start, NSMaxRange(affected)), length)
        let lower = max(0, start - 1)
        let upper = min(length, end + 1)
        return NSRange(location: lower, length: upper - lower)
    }

    /// Restricts parsing to the edited lines and any numbered lines directly
    /// connected to their outer edges. A long note therefore pays only for the
    /// list blocks touched by the structural edit.
    private static func localSearchRange(in text: NSString, around probe: NSRange) -> NSRange {
        var range = text.lineRange(for: probe)

        while range.location > 0 {
            let previous = lineRanges(in: text, containing: range.location - 1)
            guard previous.full.location < range.location,
                  parse(text.substring(with: previous.content), at: previous.content) != nil else {
                break
            }
            range = NSRange(location: previous.full.location,
                            length: NSMaxRange(range) - previous.full.location)
        }

        while NSMaxRange(range) < text.length {
            let next = lineRanges(in: text, containing: NSMaxRange(range))
            guard next.full.location >= NSMaxRange(range),
                  parse(text.substring(with: next.content), at: next.content) != nil else {
                break
            }
            range.length = NSMaxRange(next.full) - range.location
        }
        return range
    }

    private static func lineRanges(in text: NSString,
                                   containing location: Int) -> (full: NSRange, content: NSRange) {
        var start = 0
        var end = 0
        var contentsEnd = 0
        text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd,
                          for: NSRange(location: location, length: 0))
        return (NSRange(location: start, length: end - start),
                NSRange(location: start, length: contentsEnd - start))
    }

    private static func intersects(_ block: [Item], probe: NSRange) -> Bool {
        guard let first = block.first, let last = block.last else { return false }
        let blockRange = NSRange(location: first.lineRange.location,
                                 length: NSMaxRange(last.lineRange) - first.lineRange.location)
        return probe.location <= NSMaxRange(blockRange)
            && NSMaxRange(probe) >= blockRange.location
    }
}
