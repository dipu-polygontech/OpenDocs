# Engineering Task

## Status
DONE — 2026-09-19. Implements `FEATURE-OPENREADER-P6.md`'s first implementation slice, item (a): the 3 CRITICAL findings from the post-hardening audit (`FINDINGS.md`). Also fixes ODF-P6-04 (HIGH) opportunistically, since it lives in the exact method touched for ODF-P6-02 in the same file.

## Story
Post-hardening audit remediation, slice (a): critical bugs (`FEATURE-OPENREADER-P6`)

## Objective
Close the 3 CRITICAL findings from the audit register before any other remediation work: a data-loss bug in document indexing/rescan, an OOM risk in two readers, and an unguarded-exception crash risk on the first-run path.

## Fixes, by finding

**ODF-P6-01 (data loss / duplicate entries) — two-part fix, per user decision.**
1. *Dedup on index* (the user's chosen primary fix): added `DocumentRepository.findByFingerprint({displayName, sizeBytes})`, querying `documents` by case-insensitive name + exact size. `IncomingDocumentResolver.resolve()` now checks this before indexing a shared-in file; if an existing document matches and its path differs from the incoming (ephemeral cache) path, resolution returns that existing document directly — the cache-path copy is never indexed, so it can never become a duplicate row for `rescan()` to later delete.
2. *Rescan guard* (added after a follow-up question, since the dedup fix alone doesn't cover a transient permission blip): `DocumentRepositoryImpl.rescan()` now only wipes the entire `documents` table on an empty scan result if `StorageAccessService.hasAccess()` confirms access is still granted. An empty scan while access is unavailable now leaves the existing index (and every favorite/recent row) untouched instead of treating "can't scan" as "nothing exists".

Soft-delete-on-rescan (marking a missing document unavailable instead of deleting it, so BRD §7.5/§7.6's missing-file UI fires) was **not** implemented — the user chose dedup-on-index only for the duplicate-source fix. `document_repositories_test.dart`'s "prunes removed index records" test still asserts the delete-on-legitimate-removal behavior; that assertion is now only reachable when access is genuinely still granted, which is correct.

**ODF-P6-02 (OOM risk).** `ExcelReaderController`/`WordReaderController` now check `file.length()` against a 20MB `maxBytes` ceiling (matching CSV/Text's existing pattern) *before* calling `readAsBytes()`, so a huge file is rejected before being loaded into memory rather than after. `ZipSafetyGuard.check()` still runs afterward as a second layer for the ZIP-declared-uncompressed-size case.

**ODF-P6-03 (unguarded exceptions).** Every `AppSettingsRepositoryImpl` method now catches and logs (`AppLogger.error`) rather than letting a `SharedPreferences` failure propagate as an unhandled exception. Read methods fall back to their existing safe defaults (`getThemeMode` already did this); write methods (`setThemeMode`/`setLocale`/`setOnboardingComplete`/`clearSettings`) now no-op after logging instead of throwing. Deliberately did **not** migrate the interface to the `ResultFuture`/`Failure` pattern the other repositories use — that would require updating every caller (`OnboardingController`, `ThemeController`, `LocaleController`, `SettingsController`) to handle `Either`, a materially larger change than closing the actual crash risk. Flagged in the class's own doc comment as a deliberate scope line, not a silent gap.

**ODF-P6-04 (opportunistic, HIGH).** `WordReaderController._loadInitialPosition()` now sets `status.value = StateStatus.error` on a load failure instead of unconditionally `success`, matching the other 4 readers.

## Acceptance Criteria
- ODF-P6-01: met — dedup-on-index and the rescan access guard both implemented and tested.
- ODF-P6-02: met — both readers reject an oversized raw file before reading it into memory.
- ODF-P6-03: met — no `AppSettingsRepositoryImpl` method can throw an unhandled exception.
- ODF-P6-04: met (opportunistic) — Word reader's `status` now reflects load failure.

## Validation
- `flutter analyze`: 0 errors, 0 warnings, 133 infos (same baseline as `FEATURE-OPENREADER-P5/tasks/TASK-017.md`/`TASK-018.md`).
- `flutter test`: 148/150 passing — same 2 pre-existing, unrelated `FileScannerService` Windows-path-separator failures documented since `TASK-013.md`; all 8 new tests pass (2 `document_repositories_test.dart`: rescan-guard + `findByFingerprint`; 2 `incoming_document_resolver_test.dart`: dedup-match + same-path-idempotent; 2 `excel_reader_controller_test.dart`/`word_reader_controller_test.dart` each: raw-length ceiling; plus `status.value` assertions added to 3 existing Word tests; new `app_settings_repository_impl_test.dart`, 4 tests, first coverage this file has ever had).

## References
- `agentic/data/project-context/features/FEATURE-OPENREADER-P6/FINDINGS.md` ODF-P6-01/02/03/04
- `agentic/data/work-items/FEATURE-OPENREADER-P6.md` Unresolved Specification Questions (resolved 2026-09-19) — records the user's dedup-on-index + rescan-guard decision

## Out of Scope
- Soft-delete-on-rescan for ODF-P6-01 — not chosen by the user; BRD §7.5/§7.6's missing-file UI remains unreached via this path.
- Migrating `AppSettingsRepository` to `ResultFuture`/`Failure` — flagged as a deliberate, larger, separate change.
- Every other finding in the register — this task is slice (a) only; slices (b) through (h) remain.
