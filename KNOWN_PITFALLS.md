# KNOWN_PITFALLS.md

## Pitfall #1

Duplicate Firestore queries between Home and Homework.

Status

Fixed.

---

## Pitfall #2

Today's Lesson and Homework were reading different collections.

Status

Fixed.

---

## Pitfall #3

Storage upload crashes because Firebase Storage is disabled.

Status

Known limitation.

---

## Pitfall #4

Student chat should resolve teacher through halaqa first.

Status

Fixed.

---

## Pitfall #5

Points could be earned repeatedly by reopening homework.

Status

Fixed by completedAt + isSubmitted.