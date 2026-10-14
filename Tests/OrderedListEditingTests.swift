import AppKit

enum OrderedListEditingTests {
    static func run(_ check: (_ condition: Bool, _ message: String) -> Void) {
        deletionRenumbersFollowingItems(check)
        middleInsertionRenumbersFollowingItems(check)
        indentationRenumbersSiblings(check)
        outdentationRenumbersSiblings(check)
    }

    private static func deletionRenumbersFollowingItems(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n2. B\n3. C\n4. D")
        let line = (view.string as NSString).range(of: "2. B\n")
        view.setSelectedRange(line)
        view.deleteBackward(nil)
        check(view.string == "1. A\n2. C\n3. D",
              "deleting item 2 must renumber 3 and 4 to 2 and 3")
    }

    private static func middleInsertionRenumbersFollowingItems(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n2. B\n3. C\n4. D")
        let line = (view.string as NSString).range(of: "2. B")
        view.setSelectedRange(NSRange(location: NSMaxRange(line), length: 0))
        view.insertNewline(nil)
        check(view.string == "1. A\n2. B\n3. \n4. C\n5. D",
              "inserting item 3 must shift the old 3 and 4 to 4 and 5")
    }

    private static func indentationRenumbersSiblings(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n2. B\n3. C")
        let item = (view.string as NSString).range(of: "2. B")
        view.setSelectedRange(NSRange(location: NSMaxRange(item), length: 0))
        view.insertTab(nil)
        check(view.string == "1. A\n1.1. B\n2. C",
              "indenting item 2 must make it a child and renumber the next sibling")
    }

    private static func outdentationRenumbersSiblings(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n1.1. B\n2. C")
        let item = (view.string as NSString).range(of: "1.1. B")
        view.setSelectedRange(NSRange(location: NSMaxRange(item), length: 0))
        view.insertBacktab(nil)
        check(view.string == "1. A\n2. B\n3. C",
              "outdenting a child must place it in the parent sequence")
    }

    private static func makeView(_ source: String) -> TaskTextView {
        let storage = NSTextStorage(string: source)
        let layout = HidingLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        return TaskTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500),
                            textContainer: container)
    }
}
