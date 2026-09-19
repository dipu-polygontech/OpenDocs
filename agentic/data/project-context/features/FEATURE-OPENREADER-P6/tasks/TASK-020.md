# Engineering Task

## Status
DONE — 2026-09-19. Implements `FEATURE-OPENREADER-P6.md`'s implementation slice (b): the HIGH-severity permissions cluster (ODF-P6-09/10/11). One fix applied (ODF-P6-10); two re-assessed and deferred rather than fixed in place (ODF-P6-09/11), with a documented reason each.

## Story
Post-hardening audit remediation, slice (b): permissions cluster (`FEATURE-OPENREADER-P6`)

## Fixes and re-assessments, by finding

**ODF-P6-10 (fixed).** `DocumentInteractionController._verifyStillAccessible()` now calls `StorageAccessService.isPermanentlyDenied()` when access is missing, and offers "Open Settings" (→ `openSettings()`) instead of "Grant Access" (→ `requestAccess()`) when true — mirroring `OnboardingController.allowAccess()`'s existing handling of the identical status. Previously, a user who had already permanently denied the permission got a "Grant Access" button that silently no-opped (`permission_handler` won't re-prompt once permanently denied), with no way to recover from this specific entry point.

**ODF-P6-09 (re-assessed, deferred to slice (g), not fixed in place).** Before implementing the finding's literal suggestion (SDK-version-aware Android 13+ `READ_MEDIA_*` handling), verified two things first:
1. `MediaService`/`use_media_picker.dart` (2 of the 3 "inconsistent" code paths the finding names) have zero references anywhere outside themselves — confirmed dead code by grep across `lib/`, matching ODF-P6-40's independent finding. `StorageAccessService` is the only *live* permission path today.
2. Re-read the accepted `ADR-OPENREADER-storage-access.md` (`FEATURE-OPENREADER-P1`): OpenReader's committed storage-access model is `MANAGE_EXTERNAL_STORAGE` ("All files access"), chosen specifically because it grants full filesystem read regardless of Android version and doesn't restrict discovery to MediaStore-indexed locations (Alternative 2 in that ADR, MediaStore-scoped queries, was explicitly rejected for under-discovering documents). Android 13+'s `READ_MEDIA_IMAGES`/`VIDEO`/`AUDIO` permissions only gate MediaStore access to media files — they would not grant access to arbitrary PDFs/DOCX/XLSX/TXT/CSV files sitting outside MediaStore's indexed locations, so adding them would not close a real gap for this app's actual access pattern.

Given both, implementing the finding's specific suggestion would mean adding permission-request logic this session has no device to verify, for a permission that doesn't actually apply to how this app reads files. The real, live-code part of the finding ("3 inconsistent paths") resolves itself once the 2 dead-code paths are removed in slice (g) — deferred there rather than fixed here.

**ODF-P6-11 (deferred to slice (g), not fixed in place).** Lives entirely inside `MediaService.pickFiles()`, one of the two files confirmed dead in the ODF-P6-09 re-assessment above. Not polished in place — will be fixed-and-kept or deleted per whatever the user decides in slice (g)'s per-item dead-code approval, consistent with `TASK-017.md`'s precedent of not unilaterally acting on flagged-but-unapproved dead code.

**ODF-P6-15 (HIGH, originally slotted for slice (c)) also re-flagged here** for the same reason — same dead file as ODF-P6-11 (`use_media_picker.dart`). Moved into the "deferred to slice (g)" bucket rather than fixed independently in slice (c) when reached, to avoid fixing the same dead code twice under two different slice labels.

## Acceptance Criteria
- ODF-P6-10: met — permanently-denied users now see a working recovery path.
- ODF-P6-09/11/15: re-assessed, not independently fixed — tracked for the slice (g) dead-code decision instead, with the reasoning recorded here and in `FINDINGS.md` so slice (g) doesn't have to re-derive it.

## Validation
- `flutter analyze`: 0 errors, 0 warnings, 133 infos (same baseline).
- `flutter test`: full suite green except the same 2 pre-existing `FileScannerService` failures; 1 new test (`document_interaction_controller_test.dart`: permanently-denied → Open Settings path).

## References
- `agentic/data/project-context/features/FEATURE-OPENREADER-P6/FINDINGS.md` ODF-P6-09/10/11/15
- `agentic/data/project-context/features/FEATURE-OPENREADER-P1/adr/ADR-OPENREADER-storage-access.md` — the accepted storage-access model this task's ODF-P6-09 re-assessment relies on
- `TASK-017.md` (`FEATURE-OPENREADER-P5`) — precedent for not unilaterally acting on flagged dead code without per-item approval

## Out of Scope
- Slice (g)'s actual dead-code deletion decision for `MediaService`/`use_media_picker.dart` — this task only records that ODF-P6-09/11/15 are downstream of that decision, it doesn't make the decision.
- Slice (c) (remaining HIGH findings) — not started by this task.
