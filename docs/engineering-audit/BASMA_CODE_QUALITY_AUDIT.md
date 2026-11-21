# BASMA Code Quality Audit (Stage A)

**Date:** 2026-11-16  
**SDK:** Dart `^3.11.1` (pubspec); Flutter via FVM (`.fvmrc` present).  
**No refactors in this stage.**

---

## 1. Verified facts

### 1.1 Architecture adherence

- Feature folders with data/domain/presentation are the dominant pattern (ADR-001).
- Repository contracts in domain for chat and several role features — good DIP samples.
- Violations are local (fat widgets, Firebase types leaking toward presentation via models) — sample-based, not exhaustive AST.

### 1.2 Duplication / SOLID themes (Existing Known + Potential)

| Theme | Taxonomy | Examples / refs |
|-------|----------|-----------------|
| Bottom nav chrome | **Partially Resolved** vs AUD-041 | Single `AppFloatingBottomNav`; labels still per role |
| Multiple subpage scaffolds | Existing Known AUD-042 | App/Admin/Parent/Supervisor scaffolds |
| Hardcoded colors / opacity | Existing Known AUD-047 | `Colors.` ~2647/179 files; `withOpacity` 41; `withValues` 296 |
| Hardcoded Arabic UI strings | Existing Known AUD-043–045 | ~**4625** Arabic literals / 332 files; **0** `.arb` |
| Error mapping inconsistency | Existing Known AUD-048 | Partially improved for index/callable copy |
| Fat pages (SRP) | Potential Risk | 15+ presentation files >1000 lines (e.g. parent_child_profile 1573, teacher_evalutation 1443, supervisor_dashboard 1403) |
| Firestore in presentation | Confirmed (BASMA-108) | See Architecture audit leak list |
| Typo’d filename retained | Potential Risk | `teacher_evalutation_page.dart` |

### 1.3 Deprecated APIs

- `withOpacity` usage remains; Flutter 3.27+ prefers `withValues` — confirm against pinned SDK before mass replace (**Potential Risk** / P3).
- Do not adopt experimental APIs.

### 1.4 Logging

- ~24 `print`/`debugPrint` under `lib/` — prefer structured safe logger (**P2**).

### 1.5 Dependencies (spot check)

- `flutter_bloc`, `go_router`, Firebase suite present and central.
- Full dependency health (abandoned packages) = **Blocked Verification** this pass (no `dart pub outdated` run recorded).

---

## 2. Measured results

| Signal | Count / note |
|--------|----------------|
| Flutter test dart files | 282 |
| withOpacity hits | ~41 |
| ListView vs builder | ~74 vs ~14 |
| Feature modules | 29 |

---

## 3. Recommendations

1. Prefer targeted extractions widgets where rebuild isolation is proven — not a mega shared library (ADR / AI_RULES).
2. Design-system tokens after Security/Firebase Stage D batches.
3. L10n/Dark mode remain owner-gated (product deferral).

---

## 4. Unresolved questions

- Dead code percentage / unreachable features — see Integration + historical orphan audit.
- Analyzer issue count (`flutter analyze`) — not executed this Stage write.
