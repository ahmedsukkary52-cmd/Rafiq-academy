# Seed: حقول واجباتي على `assignments`

مصدر الحقيقة الواحد: **`assignments`** (نفس collection كارت «درس اليوم»).

التطبيق يزرع تلقائياً عند أول قراءة لو `tasks` فاضية:

- `StudentRemoteDatasourceImpl._ensureHomeworkFieldsOnAssignment`
- `HomeworkRemoteDatasourceImpl._ensureHomeworkFields`

**لا تُزرع** روابط صوت/PDF وهمية ولا مهمة اختبار فهم (محتوى تعليمي مخترع).

## شكل المستند

```json
{
  "studentId": "<uid>",
  "assignedBy": "<teacherUid>",
  "halaqaId": "<optional>",
  "newMemorizationRange": "سورة الملك - الآيات ١-١٦",
  "reviewRange": "الآيات ١-٨",
  "dueDate": "<Timestamp>",
  "title": "سورة الملك - الآيات ١-١٦",
  "tasks": [
    { "id": "t1", "title": "قراءة: ...", "points": 20, "isCompleted": false, "kind": "reading" },
    { "id": "t2", "title": "الاستماع للتلاوة كاملة", "points": 15, "isCompleted": false, "kind": "listening" },
    { "id": "t3", "title": "تسميع: ...", "points": 30, "isCompleted": false, "kind": "recitation" }
  ],
  "attachments": [],
  "isSubmitted": false
}
```

ملاحظات:

- `teacherVoiceNote` اختياري — يُضاف فقط عند وجود تسجيل حقيقي من المعلم.
- المستندات القديمة التي تحتوي روابط وهمية لا تُهاجَر تلقائياً؛ البذر الجديد فقط نظيف.

## التحقق

1. أنشئ/اقرأ تكليفاً بلا `tasks`.
2. تأكد أن الحقول زُرعت بدون صوت/PDF وهمي وبدون مهمة quiz.
3. تأكد أن كارت درس اليوم وصفحة واجباتي يتحدثان (streams).
