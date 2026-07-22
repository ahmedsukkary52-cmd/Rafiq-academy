# ARCHITECTURE_DECISIONS.md

> This document records important architectural decisions made during the project.
>
> AI agents must respect these decisions.
>
> Do not replace or redesign them unless explicitly requested.

---

# ADR-001

## Title

Feature-first Clean Architecture

### Status

Accepted

### Decision

The project is organized by feature.

Every feature owns:

- data
- domain
- presentation

Cross-feature business logic is not allowed.

---

# ADR-002

## Title

Single Source of Truth

### Status

Accepted

### Decision

Every business concept has exactly one source of truth.

No duplicate repositories.

No duplicate Firestore queries.

No duplicate collections.

Always reuse existing implementations.

---

# ADR-003

## Title

Home Pages are Dashboards

### Status

Accepted

### Decision

Home pages summarize information only.

Detailed business logic belongs inside dedicated features.

Home pages should never own feature logic.

---

# ADR-004

## Title

Assignments are the source of Today's Lesson

### Status

Accepted

### Decision

Today's Lesson and Homework both read from:

assignments

They must never become separate implementations.

---

# ADR-005

## Title

Student ↔ Teacher Chat Resolution

### Status

Accepted

### Decision

Teacher resolution order:

1.

studentProfiles.halaqaId

↓

halaqat.teacherId

2.

Fallback

assignments.assignedBy

No alternative resolution strategies should be introduced.

---

# ADR-006

## Title

Storage Disabled

### Status

Accepted

### Decision

Firebase Storage is intentionally disabled.

Upload features should gracefully inform users that uploads are temporarily unavailable.

Fake upload implementations are forbidden.

---

# ADR-007

## Title

Feature Ownership

### Status

Accepted

### Decision

Business logic belongs to the feature that owns the concept.

Examples

Homework

↓

homework feature

Schedule

↓

schedule feature

Chat

↓

chat feature

Student feature should not become a container for unrelated business logic.

---

# ADR-008

## Title

Placeholder Policy

### Status

Accepted

### Decision

Temporary placeholders are allowed only when documented inside PROJECT_STATUS.md.

Undocumented placeholders are prohibited.

---

# ADR-009

## Title

Navigation Pattern

### Status

Accepted

### Decision

GoRouter is the single navigation mechanism.

Navigation should reuse existing routes.

Duplicate routes should not be introduced.

---

# ADR-010

## Title

Architecture Changes

### Status

Accepted

### Decision

AI agents must not redesign the architecture.

Only implement requested functionality.

Large architectural changes require explicit approval.

---

# ADR-011

## Title

Student-Only Self-Registration

### Status

Accepted

### Decision

Self-registration is currently available only for students.

Teacher, Parent, Supervisor and Admin accounts are created by the academy/admin.

All roles can still log in normally.