# AI_RULES.md

> **Purpose**
>
> This document defines the mandatory engineering rules for all AI agents working on the Rafiq
> Academy project.
>
> Read this file **before making any code changes**.
>
> These rules are mandatory unless the user explicitly instructs otherwise.

---

## Existing Implementation Priority

Before implementing any feature:

1. Search existing implementation.
2. Understand existing business logic.
3. Extend it if possible.
4. Create new code only when no suitable implementation exists.

Prefer extending over rewriting.

Never replace working code without explicit instruction.

## Investigation Phase

During an investigation:

Identify facts.

Identify problems.

Do not redesign the architecture.

Do not propose migrations.

Do not decide ownership changes.

Only report observations.

Architectural decisions belong to the user.

# 1. Read Before Coding

Before implementing any feature, always read:

1. AI_RULES.md
2. PROJECT_STATUS.md
3. Relevant audit document (if available)
4. ARCHITECTURE_DECISIONS.md

Never start implementing a feature before understanding the current project state.

---

# 2. Existing Code Investigation (MANDATORY)

Before creating **any** new code, search the project for existing:

- Feature
- Repository
- Datasource
- UseCase
- Bloc
- Entity
- Model
- Widget
- Route
- Firestore query
- Helper
- Extension
- Utility

Reuse existing implementations whenever possible.

Never duplicate existing business logic.

---

# 3. Architecture Rules

This project follows:

- Feature-first architecture
- Clean Architecture
- Repository Pattern
- BLoC
- Dependency Injection

Every feature must respect the existing architecture.

Never bypass the architecture for convenience.

---

# 4. Single Source of Truth

Every business concept must have only one source of truth.

Examples:

- Assignments
- Student Profile
- Halaqa
- Schedule
- Progress Report
- Chat

If an existing source already exists:

Reuse it.

Never create a second implementation for the same concept.

---

# 5. Feature Ownership

Every feature owns its own business logic.

Examples:

Homework feature owns homework logic.

Schedule feature owns schedule logic.

Chat feature owns chat logic.

Progress Report feature owns report logic.

Student feature owns only student-specific data such as:

- Profile
- Avatar
- Personal settings

Do not move unrelated business logic into Student feature.

---

# 6. Home Pages

Home pages are dashboards only.

A Home page:

- summarizes information
- navigates to feature pages

A Home page MUST NOT:

- duplicate Firestore queries
- own business logic
- implement feature-specific repositories

Always reuse existing feature use cases.

---

# 7. Firestore Rules

Firestore is the primary data source.

Never replace Firestore with:

- hardcoded data
- fake repositories
- temporary local lists

unless explicitly requested.

Always reuse existing collections before creating new ones.

Avoid duplicate collections representing the same business concept.

---

# 8. Firebase Storage

Firebase Storage is currently disabled.

Never implement fake upload logic.

Never simulate successful uploads.

Instead:

- gracefully disable upload features
- explain why the feature is unavailable
- prevent crashes

---

# 9. Bloc Rules

Every feature should expose state through BLoC.

Avoid business logic inside:

- Widgets
- UI pages
- Builders

Business logic belongs inside:

UseCases

Repositories

Bloc

Keep widgets as presentation only.

---

# 10. UI Rules

Every screen must support:

✓ Loading

✓ Success

✓ Empty State

✓ Error State

✓ Retry

Never leave a blank screen.

Never crash because data is unavailable.

---

# 11. Error Handling

Handle:

- network failures
- Firestore permission errors
- timeout
- missing documents
- deleted records
- null values

Show meaningful UI.

Never silently ignore failures.

---

# 12. Navigation

Reuse existing GoRouter routes.

Never create duplicated navigation paths.

Use existing navigation patterns.

---

# 13. Performance

Avoid unnecessary:

- rebuilds
- Firestore reads
- nested listeners
- duplicate streams

Reuse existing streams whenever possible.

Prefer lazy loading when appropriate.

---

# 14. Dependency Injection

Always use the existing DI container.

Never manually instantiate repositories if DI already provides them.

---

# 15. Code Style

Match the existing project style.

Naming conventions should remain consistent.

Do not introduce a different coding style.

---

# 16. Shared Components

Before creating:

- Widget
- Dialog
- Bottom Sheet
- Card
- Tile
- Button

Search inside:

shared/widgets

Reuse existing widgets whenever possible.

---

# 17. Feature Scope

Implement only the requested feature.

Do not modify unrelated files.

Do not refactor unrelated code.

Do not introduce architectural changes unless requested.

---

# 18. Placeholder Policy

Temporary placeholders are allowed only when:

- approved by the user
- documented in PROJECT_STATUS.md

Never leave undocumented placeholder implementations.

---

# 19. Before Finishing

Before considering a task complete, verify:

✓ No duplicated logic

✓ No duplicated repositories

✓ No duplicated Firestore queries

✓ Architecture respected

✓ Existing code reused

✓ Proper error handling

✓ Loading/Empty/Error implemented

✓ Responsive UI maintained

✓ No unrelated files modified

✓ Code compiles without errors

---

# 20. Absolute DON'Ts

Never:

❌ Create duplicate repositories

❌ Create duplicate blocs

❌ Create duplicate models

❌ Create duplicate entities

❌ Create duplicate Firestore collections

❌ Create mock business logic

❌ Hardcode production data

❌ Ignore existing architecture

❌ Break feature boundaries

❌ Introduce unrelated refactoring

❌ Modify unrelated files

❌ Invent business rules

If project behavior is unclear:

Stop.

Ask for clarification.

Never guess.

---

# Final Principle

The goal is not simply to make the feature work.

The goal is to extend the existing architecture while keeping the project consistent, maintainable,
scalable, and free from duplicated business logic.