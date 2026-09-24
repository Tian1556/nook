# Remove iCloud Sync Implementation Plan

1. Remove iCloud lifecycle calls from `AppDelegate`.
2. Remove the sync preference, model state, settings tab, and localization keys.
3. Delete the iCloud folder, document, index, planning, gateway, and runner modules.
4. Delete sync-only tests and remove them from the test entry point.
5. Remove the sync-only `NoteStore.absorb` API and update the README for local-only storage.
6. Run residual-reference checks, the complete test script, and a universal release build.
7. Commit and push the verified change to `origin/main` without moving the existing baseline tag.
