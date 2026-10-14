import AppKit

enum OrderedListEditingTests {
    static func run(_ check: (_ condition: Bool, _ message: String) -> Void) {
        deletionRenumbersFollowingItems(check)
        middleInsertionRenumbersFollowingItems(check)
        newlinePreservesMarkerFormatting(check)
        indentationRenumbersSiblings(check)
        outdentationRenumbersSiblings(check)
        imageLineDeletionRenumbersMergedBlocks(check)
        compositionDefersRenumberingUntilCommit(check)
        directCompositionCommitRunsDeferredRenumbering(check)
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
        let view = makeView("1) A\n2)    B\n3) C")
        let item = (view.string as NSString).range(of: "2)    B")
        view.setSelectedRange(NSRange(location: NSMaxRange(item), length: 0))
        view.insertTab(nil)
        check(view.string == "1) A\n1.1)    B\n2) C",
              "indenting must keep the delimiter and spacing while renumbering siblings")
    }

    private static func outdentationRenumbersSiblings(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1) A\n1.1)    B\n2) C")
        let item = (view.string as NSString).range(of: "1.1)    B")
        view.setSelectedRange(NSRange(location: NSMaxRange(item), length: 0))
        view.insertBacktab(nil)
        check(view.string == "1) A\n2)    B\n3) C",
              "outdenting must keep the delimiter and spacing in the parent sequence")
    }

    private static func newlinePreservesMarkerFormatting(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1)   A\n2)   B")
        let first = (view.string as NSString).range(of: "1)   A")
        view.setSelectedRange(NSRange(location: NSMaxRange(first), length: 0))
        view.insertNewline(nil)
        check(view.string == "1)   A\n2)   \n3)   B",
              "a continued item must inherit its delimiter and separator spacing")
    }

    private static func imageLineDeletionRenumbersMergedBlocks(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let marker = ImageStore.token(id: "ordered-list-test-image", width: nil)
        let view = makeView("1. A\n\(marker)\n4. C")
        guard let token = ImageStore.tokens(in: view.string).first,
              let storage = view.textStorage else {
            check(false, "image deletion test must create a valid image marker")
            return
        }
        storage.addAttribute(.notyHidden, value: true, range: token.range)
        view.deleteImageToken(token)
        check(view.string == "1. A\n2. C",
              "removing an image line between numbered blocks must renumber the merged list")
    }

    private static func compositionDefersRenumberingUntilCommit(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n3. B")
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        view.setMarkedText("中", selectedRange: NSRange(location: 1, length: 0),
                           replacementRange: NSRange(location: NSNotFound, length: 0))
        check(view.hasMarkedText(), "the IME regression test must establish marked text")

        view.renumberOrderedLists(from: 0, through: (view.string as NSString).length)
        check(view.string.contains("\n3. B"),
              "numbering must not change while the input method owns marked text")

        view.unmarkText()
        check(view.string == "1. A\n2. B中",
              "deferred numbering must run immediately after composition commits")
    }

    private static func directCompositionCommitRunsDeferredRenumbering(
        _ check: (_ condition: Bool, _ message: String) -> Void
    ) {
        let view = makeView("1. A\n3. B")
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        view.setMarkedText("文", selectedRange: NSRange(location: 1, length: 0),
                           replacementRange: NSRange(location: NSNotFound, length: 0))
        view.renumberOrderedLists(from: 0, through: (view.string as NSString).length)
        let marked = view.markedRange()
        view.insertText("文", replacementRange: marked)

        check(!view.hasMarkedText(), "direct IME commit must end marked text")
        check(view.string == "1. A\n2. B文",
              "direct IME commit must run the deferred numbering pass")
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
