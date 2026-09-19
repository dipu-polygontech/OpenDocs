# FEATURE-OPENREADER-P6: Post-Hardening Audit Remediation

## Request and scope

User asked for a full-codebase review after `FEATURE-OPENREADER-P5` (hardening) closed: "review, audit full code, find out gaps, bugs, and ux improvements." Executed as four parallel read-only audit passes (readers; core data layer; core presentation/services; feature screens), each reading its scope in full and cross-referencing the BRD. Findings consolidated into `agentic/data/project-context/features/FEATURE-OPENREADER-P6/FINDINGS.md` (40 IDed findings: 3 CRITICAL, 14 HIGH, 10 GAP, 10 UX, 3 CLEANUP — plus a rollup of test-coverage gaps not individually IDed).

This is not a new BRD phase — it's remediation against defects and unmet requirements discovered by auditing Phases 1–5's own shipped code. Classification: cross-module, mixed-severity (one item is a genuine data-loss bug), so this is scoped as a Feature-level work item per the Universal Planning Rule rather than exploded into full Sprint Planning — each finding becomes a Task at implementation time, batched into slices below, the same pattern `FEATURE-OPENREADER-P5` used.

## Requirements and evidence

Full register with file:line evidence lives in `agentic/data/project-context/features/FEATURE-OPENREADER-P6/FINDINGS.md`. Summary by severity:

| Severity | Count | IDs |
|---|---|---|
| CRITICAL | 3 | ODF-P6-01, 02, 03 |
| HIGH | 14 | ODF-P6-04 through 17 |
| GAP (BRD-required, unimplemented) | 10 | ODF-P6-18 through 27 |
| UX | 10 | ODF-P6-28 through 37 |
| CLEANUP (dead code) | 3 | ODF-P6-38, 39, 40 |

Status of every finding not yet listed as DONE below is **PROPOSED**. Per-slice `TASK-XXX.md` docs are created under `agentic/data/project-context/features/FEATURE-OPENREADER-P6/tasks/` as each slice is actually implemented (matching `FEATURE-OPENREADER-P5`'s own precedent — task docs written at implementation time, not speculatively upfront).

**Slice progress:**
- (a) CRITICAL — **DONE** (2026-09-19, [TASK-019.md](../project-context/features/FEATURE-OPENREADER-P6/tasks/TASK-019.md)): ODF-P6-01, 02, 03, plus ODF-P6-04 (HIGH, fixed opportunistically in the same file/method as ODF-P6-02).
- (b) HIGH, permissions cluster — **DONE** (2026-09-19, [TASK-020.md](../project-context/features/FEATURE-OPENREADER-P6/tasks/TASK-020.md)): ODF-P6-10 fixed; ODF-P6-09/11 re-assessed and deferred to slice (g) (both are dead-code-only, confirmed against the storage-access ADR).
- (c) HIGH, remainder — **DONE** (2026-09-19, [TASK-021.md](../project-context/features/FEATURE-OPENREADER-P6/tasks/TASK-021.md)): ODF-P6-05/06/07/12/13/14/16/17 fixed; ODF-P6-08 re-assessed and downgraded (unreachable in production — no UI calls `toggleLocale()`). ODF-P6-33 (slice d) and one test-coverage rollup item fixed opportunistically in the same touch.
- (d) UX quick wins — ODF-P6-33 already done via slice (c); ODF-P6-28/29/31/32/36/37 remain.
- (e) New accessibility gaps — not started.
- (f) GAP items — not started.
- (g) Dead-code cleanup — not started.
- (h) Test-coverage backfill — partially covered by slice (a)'s own new tests (rescan-guard, `findByFingerprint`, `AppSettingsRepositoryImpl` — its first-ever test coverage); the remaining rollup items in `FINDINGS.md` are still open.

## Design boundaries

No new architectural layer is anticipated for most findings — they're bug fixes, missing-widget additions, or copy/consistency changes within existing patterns. One finding needs an actual design decision before implementation, flagged below rather than decided unilaterally (`AGENTS.md`: never invent missing business rules, never infer human approval).

**ODF-P6-01 needs a document-identity decision.** The bug has two independent contributing causes and the fix could address either or both:
1. *Dedup on index*: when `IncomingDocumentResolver` indexes a shared-in file, match it against an already-indexed document (by size + display name, or a content hash) before creating a new row, instead of trusting the incoming cache path as a new identity.
2. *Soft-delete on rescan*: stop letting `rescan()`'s cascade delete favorite/recent rows outright when a previously-indexed path disappears — instead mark the document row unavailable (BRD §7.5/§7.6's "missing/unavailable state") and let the existing `DocumentInteractionController._verifyStillAccessible` UI handle it, rather than deleting the row and losing the favorite/recent status.

These aren't mutually exclusive (dedup prevents the duplicate from ever existing; soft-delete makes any future disappearance — including legitimate file deletion — recoverable in the UI instead of silent). Implementation order and whether to do one or both is one of this document's Unresolved Questions below.

**Dead-code removal (ODF-P6-38/39/40) requires the same per-item approval `TASK-017` used** for the prior cleanup pass (`FEATURE-OPENREADER-P5`) — the user was asked and explicitly chose removal there before anything was deleted. Same process applies here: propose removal, don't delete unilaterally.

**Content-dependent gaps** (ODF-P6-24's Privacy Policy text/link, ODF-P6-23's Author-metadata field naming) need real content or a product decision, not an invented placeholder — flagged in Unresolved Questions.

## Proposed implementation order

Mirrors `FEATURE-OPENREADER-P5`'s own lettered-slice pattern — small, independently verifiable, most-impactful first:

- **(a) CRITICAL bugs** — ODF-P6-01 (pending the design decision above), 02, 03. Data-loss and OOM-risk fixes; highest priority regardless of what else gets scoped in.
- **(b) HIGH bugs, permissions cluster** — ODF-P6-09, 10, 11 together (all three touch the same storage/media-permission surface; fixing them independently would leave the inconsistency ODF-P6-09 flags).
- **(c) HIGH bugs, remainder** — ODF-P6-04, 05, 06, 07, 08, 12, 13, 14, 15, 16, 17. Independent, can be split further or batched; 16 (Excel/CSV search debounce) is the one with a direct BRD corner-case citation (100k+ row sheets) so it should not slip.
- **(d) UX quick wins** — ODF-P6-28, 29, 31, 32, 33, 36, 37 (no design decision needed, small diffs).
- **(e) New accessibility gaps** — ODF-P6-34, 35 (small, same pattern as the just-closed ODF-P5-08).
- **(f) GAP items (net-new BRD-required features)** — ODF-P6-18 through 27. Larger than (a)-(e); each is closer to a small feature than a bug fix (favorite icon, grid view, sort-by-type, sort-favorites, PDF bookmarks/links, pinch zoom, delimiter detection, Author metadata, About-section content). Likely needs its own priority pass rather than one slice — proposed as last because none of these are correctness bugs, but flagged as real, currently-unplanned scope.
- **(g) Dead-code cleanup** — ODF-P6-38/39/40, pending per-item approval as described above.
- **(h) Test-coverage backfill** — at minimum the `rescan()`-outside-scan-roots regression test (would have caught ODF-P6-01), the stale CSV-isolate test comment, and a rapid-keystroke test for whichever of ODF-P6-05/16 gets fixed.

Not yet confirmed by the user — see Unresolved Questions.

## Unresolved Specification Questions (resolved 2026-09-19)

1. **ODF-P6-01 remediation scope.** RESOLVED — dedup-on-index: match an incoming shared-in file against an already-indexed document before creating a new row, so the duplicate (and the downstream rescan-cascade deletion) never occurs. Soft-delete-on-rescan was not chosen; not in scope unless revisited later.
2. **Which slice(s) to implement now.** RESOLVED — full lettered order (a) through (h).
3. **Dead-code cleanup (g).** RESOLVED — included in this pass, with per-item approval as each item is reached, same process `TASK-017` used.
4. **GAP slice (f) content items.** RESOLVED:
   - ODF-P6-24 (About section): "GitHub" row links to `https://github.com/macdipu/OpenReader` (the repo's current home); "Privacy Policy" row links to a new `PRIVACY.md` written into the repo (local-only/no-server/no-analytics content, matching Settings' existing claim) via its GitHub blob URL.
   - ODF-P6-23 (Author metadata): PDF + Office (docx/xlsx) only, sourced from each format's own metadata API; the row is omitted entirely when no author is present (matches how other optional File Information fields already behave) — not shown for CSV/Text, which have no such metadata.

## Validation and handoff
Not started. Will be filled in per slice as `TASK-XXX.md` docs land, following `FEATURE-OPENREADER-P5`'s pattern (status/evidence per finding, `flutter analyze`/`flutter test` verification per slice).

## Process note
Routed through the same scoping approach as `FEATURE-OPENREADER-P1`–`P5` — not run through the `agentic-runtime` CLI task protocol (no governed run exists for this scoping pass). `context_status` in `agentic/data/project-context/project.yaml` remains `PARTIAL`; this document does not change that.
