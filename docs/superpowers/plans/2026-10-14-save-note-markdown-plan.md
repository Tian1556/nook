# Current Note Markdown Export Implementation Plan

1. Add focused tests for current-note Markdown rendering, safe default names, image-link rewriting, duplicate images, and failure before Markdown replacement.
2. Expose a read-only image export payload from `ImageStore` with original bytes and a content-derived extension.
3. Add a testable single-note export planner/writer in `Transfer`, then connect it to an `NSSavePanel` entry point that flushes the current note and reveals successful output.
4. Pass one export callback into `TaskTextView` for the body context menu, keeping filesystem work outside the editor.
5. Add matching export buttons to the deck note, floating note, and library detail headers.
6. Add a configurable in-note shortcut with default `Command-Shift-S`, duplicate detection, and window-local handling for all three note surfaces.
7. Add Chinese and English localization, run all regression and local-only checks, then build universal version `1.9.2` build `198`.
8. Package `Nook-1.9.2-local.5.dmg`, verify the mounted app, push `main`, tag the commit, and publish the private GitHub release as latest.
