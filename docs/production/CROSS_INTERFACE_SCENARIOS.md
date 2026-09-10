# Cross-interface scenario traces

**Baseline:** `69e4207801b17fc5dede30d82b07d4a48a6a1c92`  
**Legend:** **Works** · **Partial** · **Breaks** · **No contract** · **Inconsistent**

Each scenario is the actual code path, not the hoped-for product story.

---

## 1. Admin creates Halaqa

| Step | What happens | Verdict |
|------|----------------|---------|
| Entry | Admin Management → `/admin/create-halaqa` | Works (UI) |
| Role | Admin | Works (router `/admin`) |
| Preconditions | Seeded teacher + supervisor in directory | Partial — Admin cannot create those identities |
| UI | Name, teacher dropdown, supervisor dropdown, meeting link. **No day/time.** | Breaks vs conceptual flow |
| UseCase | `CreateHalaqaUseCase` | Works |
| Bloc | `CreateHalaqaEvent` / `createHalaqaStatus` | Works |
| Write | `halaqat` doc `schedule: []`, `studentIds: []`, `status: active`; optional `teacherProfiles.halaqatIds` union | Works as coded |
| Session | None generated | No contract |
| Downstream Teacher | Halaqa appears if queried by `teacherId`; today operational days **empty** | Partial |
| Notifications | None | No contract |
| Error | Missing teacher/supervisor snackbar; network → NetworkFailure | Partial taxonomy |
| Empty | Directory empty ⇒ empty dropdowns | Partial |

**Break point:** schedule never stored (AUD-018). Conceptual flow stops before “upcoming session exists”.

---

## 2. Teacher conducts session

| Step | What happens | Verdict |
|------|----------------|---------|
| Entry | Teacher home / classes → halaqa detail / attendance | Works |
| Preconditions | `halaqat.teacherId` = teacher. **Schedule matching today** required for eval create / agenda; **not** required for attendance write (AUD-094) | Partial if created via Admin UI |
| Session open | No write. `HalaqaWeeklySessionsMapper.mapTodayOperationalDays` infers `{halaqaId}_yyyyMMdd` when a slot exists. Attendance fallback invents the same id shape without a slot. | Partial (inference, not lifecycle) |
| Overlap | Multiple slots today collapse to one day | Inconsistent with two-slot academies |
| Second session | Impossible as second SSOT id | No contract / by design of inference |
| End | `AttendancePolicy.canEditSession` vs end time / midnight | Partial — no closed flag |

**Break point:** no schedule → eval create `noSessionToday` / empty agenda. Attendance register **still saves**.

---

## 3. Attendance + evaluation

| Step | What happens | Verdict |
|------|----------------|---------|
| Attendance write | `SaveDayAttendanceUseCase` → `attendanceRecords/{sessionId}_{studentId}` | Works **even without today’s slot** (AUD-094) |
| Events | Absent transition → `StudentAbsentRecorded` / correction | Works (W4) |
| Parent inbox | If `childrenIds` contains student | Partial (link missing) |
| Open evaluation | `EvaluationService.openEvaluation` | Works **only if** session today; else `noSessionToday` |
| Requires attendance? | **No** | Inconsistent vs stated conceptual flow |
| Upsert eval | Deterministic recitation id; retire legacy duplicates; `versesRange: ''` | Works as coded; amounts missing (AUD-097) |
| Wrong session | Existing card uses stored sessionId; create uses today | Partial |
| Eval without session doc | Always (inferred) | No contract |
| Eval without attendance | Allowed | Product decision needed |
| Live-eval notify | **No** `AcademyEvent` (AUD-095) | Breaks vs homework-review path |

**Break point:** none for attendance writes even when unscheduled. Eval create needs today’s meeting. Coupling to attendance is absent (AUD-025). Progress profile not updated (scenario 4).

---

## 4. Student progress update

| Step | What happens | Verdict |
|------|----------------|---------|
| After evaluation commit | Recitation record stored (`versesRange` empty on live path) | Works as coded |
| Profile `overallProgressPercent` | Unchanged. Entity comment = current surah %; UI = overall / دقة الحفظ | Breaks + Inconsistent (AUD-096) |
| `totalVersesMemorized` / juz / streak / level | Unchanged; cannot derive verses from empty ranges | Breaks (AUD-097) |
| Teacher class bar | Reads profile | Inconsistent (shows old %) |
| Analytics grades | Reads recitationRecords honesty helpers | Works (separate metric) |
| Achievements accuracy | Uses profile % | Breaks (mislabeled) |

**Break point:** no projector (AUD-020). Meaning of the stored % is contradictory even if a projector is added.

---

## 5. Parent views result

| Step | What happens | Verdict |
|------|----------------|---------|
| Entry | Parent children / child profile / reports / evaluations | Works (UI) |
| Preconditions | `parentProfiles.childrenIds` | Breaks if empty (no writer) |
| Attendance | Query marks; % via `AttendancePolicy` | Works |
| Evaluations | Recitation reads | Works |
| Progress donut | Profile field | Partial / misleading |
| Weekly verses | `reviewedDocs.length` | Breaks (label) |
| Notifications | Absence/homework if events published | Partial |
| Payments badge | Stored payment statuses | Partial |

**Break point:** family link; progress math.

---

## 6. Parent submits payment

| Step | What happens | Verdict |
|------|----------------|---------|
| Select period + children | No issuer UI | No contract |
| Amount | Displayed from existing `payments.amount` | Partial |
| Vodafone payee | `transferDestination = ''` | Breaks (cannot know where to pay) |
| Upload proof | `SubmitPaymentProofUseCase` | Works |
| Storage | `payment_proofs/{parentId}/{paymentId}/…` | Works (rules: any signed-in can read) |
| Firestore | proof* + pending_review; does not set paid | Works (Dart) |
| Wallet alternative | Sets **paid** immediately | Breaks intended model |
| Paymob | `initiatePayment` throws | Partial leftover |
| Duplicate proof | Resubmit clears prior review fields | Works (app) |
| Notifications | None | No contract |
| Duplicate invoices | N/A — invoices not created here | No contract |

**Break point:** no invoice + no payee + wallet false paid + open rules.

---

## 7. Supervisor reviews payment

| Step | What happens | Verdict |
|------|----------------|---------|
| List | `getPaymentsForStudents` whereIn chunks | Works |
| Scope check | `_assertStudentInSupervisedHalaqa` | Works (client) |
| Approve | `status=paid`, remaining 0 | Works (Dart) |
| Reject / partial | reviewStatus only | Partial (no remainder invoice) |
| Rules | Any signed-in can write the same fields | Breaks as security |
| Notify parent | No AcademyEvent | No contract |
| Race with resubmit | Last update wins | Breaks concurrency |

**Works** as a staff UI over existing docs. **Not** a trustworthy SSOT.

---

## 8. Admin sees payment

| Step | What happens | Verdict |
|------|----------------|---------|
| Finance tab / payments page | `getPayments()` full collection | Partial (scale) |
| Totals | Sum by stored status | Partial (overdue undercount) |
| Proof visibility | Admin payment entity **omits** proof URL fields in mapping | Inconsistent vs Supervisor |
| Paid from wallet vs Vodafone | Both look like `status=paid` | Inconsistent |

**Break point:** cannot distinguish proof-confirmed vs wallet vs tampered paid; no proof on Admin entity.

---

## 9. Overdue payment

| Step | What happens | Verdict |
|------|----------------|---------|
| Clock vs dueDate | Not computed | No contract |
| Stored `overdue` | UI chips/alerts work | Partial (seed-only) |
| Reminder event | None | No contract |
| Escalation | None | No contract |

**Break point:** no writer/deriver (AUD-010).

---

## 10. Account suspension

| Step | What happens | Verdict |
|------|----------------|---------|
| From overdue | None | No contract |
| Admin disable | Teachers: `ToggleAccountStatusEvent` → `users.isActive=false`. Students: directory badge only (AUD-099) | Partial |
| Login | Auth fetch throws موقوف | Works |
| Reason field | Not on `UserEntity` | No contract |
| Feature-only suspend | Not implemented | No contract |
| Auth `user-disabled` | Mapped separately | Inconsistent two kill switches |

**Break point:** payment policy never reaches this screen.

---

## 11. Admin reactivation

| Step | What happens | Verdict |
|------|----------------|---------|
| Toggle `isActive=true` | Works for **teachers** in Admin UI. Student tab does not dispatch the same event (AUD-099). Out-of-band / reject-registration can still flip the flag. | Partial |
| Clears suspension reason | N/A (no reason) | No contract |
| Restores payments | Does not touch payments | Inconsistent vs stated policy |
| Student still on roster? | Roster not auto-cleared on disable | Partial |

---

## 12. Teacher creates homework

| Step | What happens | Verdict |
|------|----------------|---------|
| Assign sheet | Teacher class detail | Works |
| Write | `assignments` + W5 `HomeworkAssigned` per student | Works |
| Halaqa activity | Separate `halaqa_activity` repo + event `HalaqaActivityPublished` | Works |
| Mock store | Not used in production path | Inconsistent leftover |
| Parent notify | If childrenIds | Partial |
| Student see | Latest assignment policy | Works |

---

## 13. Student submits homework

| Step | What happens | Verdict |
|------|----------------|---------|
| Mark complete | Assignment `isSubmitted` + coins | Works |
| Audio recitation | Throws if flag false | Partial / accepted flag |
| Pending recitation | reviewStatus pending until teacher | Works |
| Progress profile | Unchanged | Breaks vs “progress update” story |

---

## 14. Teacher reviews submission

| Step | What happens | Verdict |
|------|----------------|---------|
| Grade write | recitationRecords + W5 `HomeworkReviewed` | Works |
| Parent/student inbox | Composer titles | Works |
| Profile % | Unchanged | Breaks |
| Analytics | Counts reviewed grades | Works |

---

## 15. Teacher ↔ Student messaging

| Step | What happens | Verdict |
|------|----------------|---------|
| Policy | Role-pair allowlist only (`ChatPermissionPolicy.canChat`); **not** halaqa ownership or `childrenIds` | Partial / Breaks as relationship (AUD-098) |
| Student gateway | Teacher from halaqa; fallback assigner | Partial (AUD-058) |
| Create | Deterministic 1:1 id; rules size ≤ 2, any two UIDs including self | Works as coded; relationship not enforced |
| Send | Text; sender must be participant | Works |
| Edit/delete | Rules false | No contract (capability) |
| Media | Not in UI | No contract |
| Pagination | Unbounded snapshots | Breaks at scale |
| Unread | Conversation unreadCounts + mark read | Works |
| Suspended user | `isActive` blocks login; existing listener if already open not specified | Partial |
| Phone | Participant fetch reads `users` (phone available to client even if UI hides) | Privacy |

---

## 16. Parent ↔ Teacher communication

| Step | What happens | Verdict |
|------|----------------|---------|
| Policy | Role-pair allowlist; **not** parent-link graph | Partial (AUD-098) |
| UI | Parent messages tab teacher filter | Works |
| Household staff | Derived from children’s halaqat teachers + admins | Partial (needs childrenIds) |
| Auto-seed | getOrCreate on tab open | Inconsistent (empty threads) |
| Parent ↔ Supervisor / Admin | Same | Works if contacts resolved |
| Parent ↔ Student | Policy **forbids** | Works (blocked) |

---

## 17. Notification generated

| Event | Producer | Firestore | Target | Push | Read | Dedupe | Failure |
|-------|----------|-----------|--------|------|------|--------|---------|
| Absence | Teacher attendance commit | `notifications` upsert | Parents (resolver) + maybe student | No | per-observer doc | eventId+observer | best-effort handler |
| Absence corrected | Same | Same | Same | No | Same | Same | Same |
| Homework assigned | Teacher assign | Same | Parent/student observers | No | Same | Same | Same |
| Homework reviewed | Teacher review | Same | Same | No | Same | Same | Same |
| Live session evaluation | **None** (AUD-095) | — | — | — | — | — | — |
| Halaqa activity | Teacher activity publish | Same | Roster students + parents | No | Same | Same | Same |
| Admin broadcast | AdminOpsBroadcast (not AcademyEvent) | `notifications.add` audience role/all | Role or all | No | `readBy` array | None (new doc each time) | Client write |
| Session reminder | **None** | — | — | — | — | — | — |
| Payment * | **None** | — | — | — | — | — | — |
| Award | **None** | — | — | — | — | — | — |
| Suspension | **None** | — | — | — | — | — | — |

**Works:** W4/W5/activity in-app. **Breaks / missing:** live eval notify, commercial + reminders + awards + push.

---

## 18. Student achievement generated

| Step | What happens | Verdict |
|------|----------------|---------|
| Auto from memorization/streak | No writer from eval/attendance | No contract |
| Manual grant | Teacher awards / Supervisor grant / Admin rewards → `achievements` H7 dual-write + optional image Storage | Works |
| Student list | Dual-read contract | Works |
| Notify | No AcademyEvent | Breaks vs “notification generated” |
| Stats | Client merge of grants | Partial scale |

**Break point:** “generated” implies automatic; freeze only has **issued** awards.

---

## Cross-role coherence map

```
Admin create halaqa [no schedule] ──x── Teacher eval / agenda
Admin create halaqa [no schedule] ──✓── Teacher attendance fallback (AUD-094)
Admin admit student ──✓── Teacher roster
W8 admit ──x── Parent childrenIds
Teacher attendance ──✓── Parent inbox (if linked)
Teacher evaluation ──x── Profile progress
Teacher evaluation ──x── AcademyEvent (AUD-095)
Teacher evaluation ──✓── Student eval list / analytics grades
Parent proof ──✓── Supervisor review (if invoice exists)
Parent proof ──x── Notifications
Supervisor approve ──✓── status paid (Dart)
Wallet pay ──✓── status paid (contradicts proof SSOT)
Overdue ──x── anything
Teacher isActive toggle ──✓── login block ──x── payment reason
Student isActive badge ──x── Admin toggle (AUD-099)
Chat 1:1 happy path ──✓──  Relationship graph ──x──  Group ──x──
```

`✓` = connected in code · `x` = missing or contradictory
)
