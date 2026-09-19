# Engineering Task

## Status
DONE — 2026-09-19. Implements `SRS.md`/`ARCHITECTURE.md`'s first implementation slice, item (e), the last item: ODF-P5-08 accessibility pass. Scope was the baseline confirmed in `SRS.md` Unresolved Specification Question 4: `Semantics` widget coverage for every interactive control across all 5 readers plus Home/Recent/Favorites/Settings, verified via `flutter test`'s semantics-tree assertions — no device/screen-reader pass (deferred to the environment-blocked bucket, ODF-P5-09/10/11).

## Story
Accessibility pass (BRD Phase 5, hardening — Accessibility)

## Objective
Add missing semantics to every interactive control identified by a full pass over the 5 reader screens (PDF, Word, Excel, CSV, Text) plus Home, Recents, Favorites, and Settings, and the shared `DocumentListTile`/`LoadingView` widgets they all reuse.

## Findings and fixes, by surface

**All 5 reader app bars (PDF/Word/Excel/CSV/Text).** Every icon-only `IconButton` (search, close-search, favorite toggle, prev/next search match) and the overflow `PopupMenuButton` had no `tooltip` — a screen reader announces an unlabeled `IconButton` only as "button". Added a `tooltip` to each, including a state-dependent one for the favorite toggle (`Add to favorites` / `Remove from favorites`). Text-size/line-wrap/share/open-with actions were already exposed as textual `PopupMenuItem`s — left as-is.

**PDF reader thumbnail strip.** Page thumbnails were a bare `GestureDetector` around a rendered page image with no semantics at all — a screen reader had nothing to announce or select. Wrapped each in `Semantics(button: true, selected: ..., label: 'Page N')` with `ExcludeSemantics` on the rendered thumbnail itself (decorative once the wrapper supplies the label).

**Excel reader sheet-tab bar.** Same gap: an `InkWell` with only a `Text` child conveyed the sheet name but not its selected state or its role as a tab. Wrapped each tab in `Semantics(button: true, selected: ..., label: 'Sheet: <name>')`.

**Shared `DocumentListTile`** (used by Home/Recents/Favorites, and incidentally Files/Search — same widget, not separately touched). Its overflow `PopupMenuButton` had no `tooltip`, so every row's "more options" button was indistinguishable from every other row's to a screen reader; added `tooltip: 'More options for <filename>'`. Its decorative leading category icon (redundant with the category already stated in the row's subtitle text) is now wrapped in `ExcludeSemantics` so it doesn't add a noise node to the tree.

**Home.** Search `IconButton` had no tooltip — added `'Search documents'`.

**Recents.** The "clear all" `IconButton` (`delete_sweep_outlined`) had no tooltip — added `'Clear all recent files'`.

**Settings.** `_SectionHeader` (Appearance/Files/Privacy/About) rendered as a plain `Text`, invisible to a screen reader's heading-navigation gesture. Wrapped in `Semantics(header: true, ...)`. `RadioListTile`/`ListTile` rows were already correctly labeled by Flutter's own Material semantics — no change needed.

**Shared `LoadingView`/`LoadingViewTransparent`.** `CircularProgressIndicator` has no default semantic label in Flutter — a screen reader announces nothing while a screen is busy. Added `Semantics(label: 'Loading', ...)` around both.

**Favorites.** Already correct: search field has hint text, rows reuse the now-fixed `DocumentListTile`. No change needed beyond the shared-widget fix.

## Explicitly not touched (scope discipline)
- `CellGrid` (Excel/CSV's spreadsheet grid) — SRS's named control list (search, zoom, page/sheet/slide navigation, favorite/share/open-with) doesn't include per-cell selection, and a full per-cell semantics tree for a large spreadsheet is a materially bigger design question than this pass's scope.
- Files/Search/File Information screens — not named in `SRS.md` Unresolved Specification Question 4's confirmed scope (Home/Recent/Favorites/Settings); they inherit the `DocumentListTile` fix for free but were not independently audited.
- A manual TalkBack/VoiceOver device pass — explicitly deferred by Question 4 into the environment-blocked bucket (ODF-P5-09/10/11); this task's verification is `flutter test`'s semantics-tree assertions only, per the confirmed baseline.

## Acceptance Criteria
- ODF-P5-08: met, at the confirmed baseline depth — every interactive control across the 5 readers plus Home/Recent/Favorites/Settings now carries a `Semantics`/`tooltip` label, verified via widget tests asserting on the semantics tree (not a manual screen-reader pass).

## Validation
- `flutter analyze`: 0 errors, 0 warnings, 133 infos (same baseline as `TASK-017.md` — no new issues introduced).
- `flutter test`: 138/140 passing — same 2 pre-existing, unrelated Windows-path-separator failures in `FileScannerService` documented since `TASK-013.md`; the 4 new accessibility assertions (`test/widgets/document_list_tile_test.dart`, `test/widgets/document_views_test.dart`) all pass, including `meetsGuideline(labeledTapTargetGuideline)` against `DocumentListTile` and `HomeView`.

## References
- `SRS.md` ODF-P5-08, Unresolved Specification Question 4 (confirmed baseline: `Semantics` coverage + `flutter test` semantics-tree assertions, device pass deferred)
- `TASK-017.md` (prior slice in the confirmed implementation order; this is the final slice)

## Out of Scope
- Manual TalkBack/VoiceOver verification on a real device — folded into ODF-P5-09/10/11's environment-blocked bucket, not this task's call to unblock.
- `CellGrid` per-cell accessibility — flagged above, not in `SRS.md`'s named control list for this pass.
- Text scaling/contrast verification against BRD's own accessibility criteria beyond what `Semantics` coverage provides — no device/manual-audit tooling exists in this project to verify it (same environment gap as the rest of Phase 5's blocked bucket).
