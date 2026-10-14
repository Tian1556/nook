# Continuous Ordered List Implementation Plan

1. Convert the deletion and middle-insertion reproductions into editor-level regression tests and verify they fail.
2. Add a pure ordered-list renumbering planner with focused flat, segmented, hierarchical, delimiter, and selection-offset tests.
3. Record structural edits in `TaskTextView` and apply minimal renumbering replacements after the user edit, guarded against re-entry and IME composition.
4. Keep the automatic changes in the current undo group and preserve the corrected selection.
5. Re-run the original reproduction, the focused regression tests, the complete editor suite, localization checks, and local-only verification.
6. Build universal version `1.9.2` build `195`, package `Nook-1.9.2-local.2.dmg`, verify the mounted image, and publish the private GitHub release.
