import Foundation

enum DeckNavigationTests {
    static func run(_ check: (_ condition: Bool, _ message: String) -> Void) {
        let ids = ["first", "second", "third"]
        check(DeckNavigation.nextID(after: "first", in: ids) == "second",
              "cycle deck must follow the deck's existing order")
        check(DeckNavigation.nextID(after: "third", in: ids) == "first",
              "cycle deck must wrap from the last note to the first")
        check(DeckNavigation.nextID(after: "only", in: ["only"]) == nil,
              "cycle deck must do nothing when only one note exists")
        check(DeckNavigation.nextID(after: "missing", in: ids) == nil,
              "cycle deck must not guess when the current note is missing")
        check(DeckNavigation.nextID(after: "missing", in: []) == nil,
              "cycle deck must safely handle an empty deck")

        let shortcut = Shortcut(keyCode: 48, modifiers: 4096)
        check(shortcut.display == "⌃⇥", "the default cycle shortcut must display as Control-Tab")
    }
}
