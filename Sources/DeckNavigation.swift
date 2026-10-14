import Foundation

/// Pure ordering rules for moving between the notes already arranged by the deck.
enum DeckNavigation {
    static func nextID(after currentID: String, in orderedIDs: [String]) -> String? {
        guard orderedIDs.count > 1,
              let current = orderedIDs.firstIndex(of: currentID) else { return nil }
        return orderedIDs[(current + 1) % orderedIDs.count]
    }
}
