# Seed: حقول واجباتي على `assignments`

مصدر الحقيقة الواحد: **`assignments`** (نفس collection كارت «درس اليوم»).

التطبيق يزرع تلقائياً عند أول قراءة لو `tasks` فاضية:

- `StudentRemoteDatasourceImpl._ensureHomeworkFieldsOnAssignment`
- `HomeworkRemoteDatasourceImpl._ensureHomeworkFields`

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
    { "id": "t3", "title": "تسميع: ...", "points": 30, "isCompleted": false, "kind": "recitation" },
    { "id": "t4", "title": "حل اختبار الفهم القصير", "points": 25, "isCompleted": false, "kind": "quiz" }
  ],
  "teacherVoiceNote": {
    "teacherName": "الشيخ عبدالرحمن",
    "audioUrl": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "durationSeconds": 45
  },
  "attachments": [
    {
      "id": "a1",
      "name": "ورقة-تمارين-التجويد.pdf",
      "url": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
      "sizeLabel": "٢٤٠ كيلوبايت"
    }
  ]
}
```

## اختبار التزامن

1. افتح Home كطالب → لو فيه تكليف قديم، هيتزرع `title/tasks/...` على نفس الـ document.
2. غيّر `newMemorizationRange` أو `title` من Firebase Console.
3. تأكد إن كارت درس اليوم وصفحة واجباتي اتحدثوا (streams لحظية).
