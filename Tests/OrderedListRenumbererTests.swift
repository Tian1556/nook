import Foundation

enum OrderedListRenumbererTests {
    static func run(_ check: (_ condition: Bool, _ message: String) -> Void) {
        check(normalized("5. A\n8. B\n9. C", around: 6) == "5. A\n6. B\n7. C",
              "a list must preserve its first number and continue from it")

        let separated = "1. A\n4. B\n\n7. X\n9. Y"
        check(normalized(separated, around: 6) == "1. A\n2. B\n\n7. X\n9. Y",
              "a blank line must keep independent numbered blocks separate")

        let ordinaryBoundary = "1. A\n4. B\nparagraph\n7. X\n9. Y"
        check(normalized(ordinaryBoundary, around: 6)
              == "1. A\n2. B\nparagraph\n7. X\n9. Y",
              "ordinary text must stop renumbering before the next list")

        let hierarchy = "1. Parent\n1.4. Child A\n1.9) Child B\n3. Parent\n8.7. Child C"
        check(normalized(hierarchy, around: 12)
              == "1. Parent\n1.1. Child A\n1.2) Child B\n2. Parent\n2.1. Child C",
              "hierarchical siblings and their parent prefixes must stay continuous")

        let mixed = "1) A\n4. B\n8) C"
        check(normalized(mixed, around: 5) == "1) A\n2. B\n3) C",
              "renumbering must preserve each line's dot or parenthesis delimiter")

        let untouched = "- bullet\n☐ task\nplain"
        check(normalized(untouched, around: 0) == untouched,
              "non-numbered text must never be rewritten")

        let widening = "9. A\n4. B\n5. C"
        let replacements = OrderedListRenumberer.replacements(
            in: widening, affectedRange: NSRange(location: 5, length: 0))
        let caret = NSRange(location: (widening as NSString).length, length: 0)
        check(OrderedListRenumberer.adjustedSelection(caret, for: replacements).location
              == caret.location + 2,
              "the caret must move with two markers widening from one digit to two")
    }

    private static func normalized(_ source: String, around location: Int) -> String {
        let replacements = OrderedListRenumberer.replacements(
            in: source, affectedRange: NSRange(location: location, length: 0))
        let result = NSMutableString(string: source)
        for replacement in replacements.reversed() {
            result.replaceCharacters(in: replacement.range, with: replacement.text)
        }
        return result as String
    }
}
