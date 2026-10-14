# Cycle Deck Shortcut Implementation Plan

1. Add a pure navigation helper and tests for next, wrap, singleton, empty, and missing-current behavior.
2. Add the persisted `scCycleDeck` shortcut with the `⌃Tab` default.
3. Add the shortcut to the settings model, duplicate detection, localized labels, and in-note shortcut list.
4. Handle the shortcut in the expanded deck's local key monitor and replace the open note without collapsing the panel.
5. Run localization checks, the complete test suite, local-only verification, and a universal Release build.
6. Commit and push the verified implementation to `origin/main` without changing the existing release tag.
