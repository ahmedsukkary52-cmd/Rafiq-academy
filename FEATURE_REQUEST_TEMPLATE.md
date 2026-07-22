# FEATURE_REQUEST_TEMPLATE.md

> Use this template whenever implementing a new feature.
>
> Read the following files first:
>
> 1. AI_RULES.md
> 2. PROJECT_STATUS.md
> 3. ARCHITECTURE_DECISIONS.md
> 4. Relevant audit file (if available)

---

# Feature Name

<Feature name>

---

# Objective

Describe exactly what this feature should accomplish.

Focus on business requirements instead of implementation details.

---

# Current Situation

Describe the current implementation.

Examples:

- UI already exists
- Placeholder implementation
- Feature partially implemented
- Feature does not exist yet

---

# Existing Code Investigation (MANDATORY)

Before writing code, search for:

- Existing feature
- Existing repository
- Existing datasource
- Existing use case
- Existing bloc
- Existing entity
- Existing model
- Existing widget
- Existing Firestore query
- Existing route

Reuse existing code whenever possible.

Never duplicate business logic.

---

# Business Rules

Describe all business rules.

Examples:

- Who can access this feature?
- What conditions must be satisfied?
- What happens after success?
- What happens after failure?

Include all edge cases.

---

# Firestore

Collections involved

- collection_a
- collection_b

Read operations

Write operations

Update operations

Delete operations

Indexes required (if any)

---

# Architecture

Specify:

Feature

Repository

Datasource

Use Cases

Bloc

States

Events

Entities

Models

Only create missing layers.

Reuse existing layers whenever possible.

---

# UI Requirements

Describe:

Pages

Widgets

Dialogs

Bottom sheets

Navigation

Animations (if needed)

Responsive behavior

---

# States

The feature must support:

- Loading
- Success
- Empty
- Error
- Retry

If applicable:

- Pagination
- Refresh
- Offline state

---

# Error Handling

Handle:

- No Internet
- Timeout
- Permission denied
- Missing document
- Deleted data
- Null values
- Unexpected exceptions

---

# Performance Requirements

Avoid:

- unnecessary rebuilds
- duplicated Firestore reads
- duplicated streams
- unnecessary listeners

Reuse existing streams whenever possible.

---

# Out of Scope

Clearly define what should NOT be implemented.

Examples:

- Teacher functionality
- Parent functionality
- Notifications
- Gamification

---

# Acceptance Criteria

The feature is complete only if:

- [ ] Business requirements implemented
- [ ] Architecture respected
- [ ] Existing code reused
- [ ] No duplicated logic
- [ ] Proper error handling
- [ ] Loading/Empty/Error states implemented
- [ ] Responsive UI maintained
- [ ] No unrelated files modified
- [ ] Code compiles successfully

---

# Important Constraints

- Do not redesign the architecture.
- Do not modify unrelated files.
- Do not create duplicate repositories.
- Do not create duplicate blocs.
- Do not invent new business rules.
- Ask for clarification if requirements are unclear.

---

# Deliverables

Implement the feature completely.

Keep the implementation consistent with the existing project architecture.

Minimize code duplication.

Prioritize maintainability and scalability.