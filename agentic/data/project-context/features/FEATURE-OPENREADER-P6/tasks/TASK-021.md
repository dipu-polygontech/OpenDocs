# Engineering Task

## Status
DONE — 2026-09-19. Implements `FEATURE-OPENREADER-P6.md`'s implementation slice (c): the remaining HIGH-severity findings not already covered by slices (a)/(b). 8 of 9 fixed; 1 (ODF-P6-08) re-assessed and downgraded rather than fixed. Also opportunistically closes ODF-P6-33 (UX, slice d) and one test-coverage rollup item, both in the same files/methods already being touched.

## Story
Post-hardening audit remediation, slice (c): remaining HIGH findings (`FEATURE-OPENREADER-P6`)

## Fixes and re-assessment, by finding

**ODF-P6-05 (stale-response races).** Added a monotonically-increasing request-id guard to both `FilesController.load()` and `SearchDocumentsController._search()`. Verified in testing that the guard is actually stricter than the finding's own framing assumed: a superseded call's result is discarded, but more than that - if a newer call starts while an older one is still awaiting `StorageAccessService.hasAccess()`, the older call never even reaches `getDocuments()` at all (its post-`hasAccess` guard check fails first). The finding described discarding a stale *response*; the actual fix also avoids the wasted *request* in that specific window.

**ODF-P6-06/12 (task_runner.dart, same file).** `DatabaseException` (sqflite) now maps to `LocalDatabaseQueryFailure` instead of the blanket `ServerFailure`; every other exception type keeps the unchanged `ServerFailure` fallback (no code anywhere branches on `Failure` subtype today, so this is additive, not a behavior change for existing callers). `AppLogger.error` now receives `error`/`stackTrace` as their own positional arguments instead of a `List` wrapper that silently dropped the real stack trace from every logged task failure.

**ODF-P6-07 (share-intent failure reporting).** Added `IncomingDocumentOutcome.indexingFailed`, distinct from `inaccessible`. A real `indexDocument()` failure (a DB write error) now surfaces as "Couldn't open this file right now. Please try again." instead of being misreported as "This file may have been moved or deleted."

**ODF-P6-08 (re-assessed, not fixed).** Before changing `Get.updateLocale`'s reassemble cost, checked who actually calls `LocaleController.toggleLocale()` - the answer is nobody. No Settings screen (or anywhere else in `lib/features`) exposes a language switch. The performance risk the finding describes is real but currently unreachable in production; changing the mechanism to fix an unreachable path risks the working initial-locale-application code for zero user-facing benefit today. Left as-is, downgraded, with the reasoning recorded in `FINDINGS.md` for whoever eventually builds a language-switch UI.

**ODF-P6-13 (locale default mismatch).** `LocaleController.currentLangCode`'s field default changed from `'bn'` to `'en'`, matching `_loadLocale()`'s own fallback - removes the cold-start locale flash.

**ODF-P6-14 (dark-mode text theme).** `AppTheme._buildTheme` now picks `AppTextTheme.darkTextTheme`/`lightTextTheme` based on `isDark` instead of always using the light one.

**ODF-P6-16 (Excel/CSV search perf).** Both controllers' `search()` now update the displayed `searchQuery` immediately but debounce the actual O(rows×columns) scan by 300ms via a cancelable `Timer`, canceled on `stopSearching()`/`onClose()` too. Matches the debounce pattern `SearchDocumentsController` already used.

**ODF-P6-17/33 (PDF jump-to-page dialog, same method).** The dialog's `TextEditingController` is now disposed after the dialog closes (ODF-P6-17). Separately, the dialog is now a `StatefulBuilder` that disables "Go" and shows inline error text until the typed value parses to a page number actually in range, instead of silently closing with no feedback on invalid input (ODF-P6-33).

**Opportunistic: stale test comment.** `test/controllers/csv_reader_controller_test.dart`'s `loaded()` helper had a comment claiming CSV parsing "runs on a real background Isolate," contradicting `CsvReaderController`'s own doc comment (parsing was moved to the calling isolate in `TASK-014`). Corrected while touching this exact file/method for the ODF-P6-16 debounce fix.

## Acceptance Criteria
- ODF-P6-05/06/07/12/13/14/16/17/33: met.
- ODF-P6-08: re-assessed, deliberately not fixed — reasoning recorded, not a silent gap.

## Validation
- `flutter analyze`: 0 errors, 0 warnings, 133 infos (same baseline).
- `flutter test`: full suite green except the same 2 pre-existing `FileScannerService` failures. New/updated tests: `test/core/task_runner_test.dart` (new, 3 tests, first coverage this file has ever had), `test/controllers/files_controller_test.dart` (new, 1 test), `test/controllers/search_controller_test.dart` (new, 1 test), `test/services/incoming_document_resolver_test.dart` (1 test updated for the new outcome), 4 assertions added/updated across `excel_reader_controller_test.dart`/`csv_reader_controller_test.dart` for the debounced search.

## References
- `agentic/data/project-context/features/FEATURE-OPENREADER-P6/FINDINGS.md` ODF-P6-05/06/07/08/12/13/14/16/17/33
- `TASK-014.md` (`FEATURE-OPENREADER-P5`) — the isolate-sendability fix the corrected test comment now accurately reflects

## Out of Scope
- ODF-P6-09/11/15 — already deferred to slice (g) by `TASK-020.md`.
- Slice (d) (UX quick wins) — not started by this task, except ODF-P6-33 opportunistically.
- Slice (e)/(f)/(g)/(h) — not started.
