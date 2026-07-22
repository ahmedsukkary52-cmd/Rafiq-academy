# ENGINEERING_CHECKLIST.md

> Use this checklist before considering any implementation complete.

---

# Architecture

- [ ] Existing architecture respected.
- [ ] Feature boundaries respected.
- [ ] No architectural shortcuts introduced.
- [ ] No business logic inside UI.

---

# Reuse

- [ ] Existing repositories reused.
- [ ] Existing blocs reused.
- [ ] Existing entities reused.
- [ ] Existing widgets reused.
- [ ] Existing routes reused.
- [ ] Existing Firestore queries reused.

---

# Duplication

- [ ] No duplicate repositories.
- [ ] No duplicate datasources.
- [ ] No duplicate blocs.
- [ ] No duplicate entities.
- [ ] No duplicate models.
- [ ] No duplicate widgets.
- [ ] No duplicated business logic.

---

# Firestore

- [ ] Existing collections reused.
- [ ] No duplicate collections created.
- [ ] Queries optimized.
- [ ] Unnecessary reads avoided.
- [ ] Proper document existence checks.
- [ ] Permission errors handled.

---

# Bloc

- [ ] Business logic inside Bloc only.
- [ ] Events are meaningful.
- [ ] States are minimal.
- [ ] No unnecessary emits.
- [ ] Streams disposed correctly.

---

# UI

- [ ] Loading state.
- [ ] Success state.
- [ ] Empty state.
- [ ] Error state.
- [ ] Retry supported.
- [ ] Responsive layout.
- [ ] Existing design system respected.

---

# Error Handling

- [ ] Network errors handled.
- [ ] Timeout handled.
- [ ] Firestore failures handled.
- [ ] Null values handled.
- [ ] Missing documents handled.
- [ ] Unexpected exceptions handled.

---

# Performance

- [ ] No unnecessary rebuilds.
- [ ] No duplicate listeners.
- [ ] No duplicate streams.
- [ ] No unnecessary Firestore reads.
- [ ] Expensive operations minimized.

---

# Navigation

- [ ] Existing routes reused.
- [ ] Navigation flow preserved.
- [ ] No duplicated routes.

---

# Code Quality

- [ ] Consistent naming.
- [ ] Readable code.
- [ ] Small methods.
- [ ] Small widgets.
- [ ] Proper separation of concerns.
- [ ] No dead code.

---

# Project Rules

- [ ] AI_RULES.md respected.
- [ ] PROJECT_STATUS.md respected.
- [ ] ARCHITECTURE_DECISIONS.md respected.
- [ ] Feature requirements fully implemented.

---

# Scope

- [ ] No unrelated files modified.
- [ ] No hidden refactoring.
- [ ] No undocumented changes.
- [ ] Only requested functionality implemented.

---

# Final Verification

- [ ] Code compiles successfully.
- [ ] No analyzer errors.
- [ ] No obvious runtime issues.
- [ ] Acceptance criteria satisfied.

---

# Stop Before Finishing

If any item above is unchecked:

The implementation is NOT complete.

Fix the issue before submitting.