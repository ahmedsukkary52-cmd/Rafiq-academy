import 'dart:convert';

import '../../../shared/domain/halaqa_name_key.dart';

/// Academy bulk import: template, CSV parsing and pre-import validation.
///
/// One CSV (Excel: "Save as → CSV UTF-8") holds every record. Records point
/// at each other with the roster's own reference codes (`ref`, e.g. T001),
/// never Firebase ids. The server (`adminImportAcademyRow`) keeps an
/// academy-wide ledger by `ref`, so a file may also reference rows that an
/// earlier import already created — or people the Admin added from the app,
/// whose academy codes (S-003, P-002, …) come from the same ledger.
enum ImportRowKind {
  teacher('teacher', 'معلم'),
  supervisor('supervisor', 'مشرف'),
  assistant('assistant', 'مساعد مدرس'),
  parent('parent', 'ولي أمر'),
  halaqa('halaqa', 'حلقة'),
  student('student', 'طالب');

  const ImportRowKind(this.wire, this.label);
  final String wire;
  final String label;

  static ImportRowKind? parse(String raw) {
    final key = halaqaNameKey(raw);
    for (final k in values) {
      if (key == k.wire || key == halaqaNameKey(k.label)) return k;
    }
    if (key == 'ولي الامر' || key == 'والد' || key == 'وليالامر') return parent;
    if (key == 'مساعد' || key == 'مساعد معلم') return assistant;
    return null;
  }
}

const academyImportColumns = [
  'type',
  'ref',
  'name',
  'teacher_ref',
  'supervisor_ref',
  'assistant_ref',
  'parent_ref',
  'halaqa_ref',
  'schedule',
  'meeting_link',
];

/// Documented template with one example of every record type. Codes follow
/// the academy convention used for people added later from the app:
/// T معلم، V مشرف، A مساعد، P ولي أمر، H حلقة، S طالب.
const academyImportTemplate =
    'type,ref,name,teacher_ref,supervisor_ref,assistant_ref,parent_ref,halaqa_ref,schedule,meeting_link\n'
    'معلم,T-001,أحمد علي,,,,,,,\n'
    'مشرف,V-001,سعاد محمد,,,,,,,\n'
    'مساعد مدرس,A-001,خالد سعيد,,,,,,,\n'
    'ولي أمر,P-001,محمد حسن,,,,,,,\n'
    'حلقة,H-001,حلقة الفجر,T-001,V-001,A-001,,,"الأحد 16:00-17:00؛ الثلاثاء 16:00-17:00",https://meet.google.com/abc-defg-hij\n'
    'طالب,S-001,يوسف محمد,,,,P-001,H-001,,\n';

const academyImportGuide = [
  'type: معلم، مشرف، مساعد مدرس، ولي أمر، حلقة، طالب.',
  'ref: رمز فريد لكل سجل (حروف إنجليزية وأرقام وشرطة)، ويُفضّل نظام الأكاديمية: T-001 معلم، V-001 مشرف، A-001 مساعد، P-001 ولي أمر، H-001 حلقة، S-001 طالب.',
  'الحلقة تحتاج teacher_ref (إلزامي) وsupervisor_ref وassistant_ref (اختياريان) وموعداً واحداً على الأقل.',
  'الموعد: اليوم ثم الوقت بنظام 24 ساعة، والمواعيد مفصولة بـ ؛ مثل: الأحد 16:00-17:00؛ الثلاثاء 16:00-17:00',
  'الطالب يحتاج parent_ref (إلزامي) وhalaqa_ref (اختياري).',
  'لا تُكتب أرقام هواتف أو بريد إلكتروني؛ بيانات الدخول تُولَّد تلقائياً.',
  'من Excel: ملف ← حفظ باسم ← CSV UTF-8.',
];

final _refPattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');
final _clockPattern = RegExp(r'^(\d{1,2}):(\d{2})$');

const _dayLabels = {
  'الاثنين': 'الاثنين',
  'الثلاثاء': 'الثلاثاء',
  'الاربعاء': 'الأربعاء',
  'الخميس': 'الخميس',
  'الجمعه': 'الجمعة',
  'السبت': 'السبت',
  'الاحد': 'الأحد',
};

class ImportSlot {
  final String day;
  final String startTime;
  final String endTime;

  const ImportSlot(this.day, this.startTime, this.endTime);

  Map<String, String> toJson() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
  };
}

class ImportRow {
  final int line;
  final ImportRowKind kind;
  final String ref;
  final String name;
  final String teacherRef;
  final String supervisorRef;
  final String assistantRef;
  final String parentRef;
  final String halaqaRef;
  final List<ImportSlot> schedule;
  final String meetingLink;

  const ImportRow({
    required this.line,
    required this.kind,
    required this.ref,
    required this.name,
    this.teacherRef = '',
    this.supervisorRef = '',
    this.assistantRef = '',
    this.parentRef = '',
    this.halaqaRef = '',
    this.schedule = const [],
    this.meetingLink = '',
  });

  Map<String, dynamic> toPayload() => {
    'kind': kind.wire,
    'ref': ref,
    'name': name,
    if (kind == ImportRowKind.halaqa) ...{
      'teacherRef': teacherRef,
      if (supervisorRef.isNotEmpty) 'supervisorRef': supervisorRef,
      if (assistantRef.isNotEmpty) 'assistantRef': assistantRef,
      'schedule': schedule.map((s) => s.toJson()).toList(),
      if (meetingLink.isNotEmpty) 'meetingLink': meetingLink,
    },
    if (kind == ImportRowKind.student) ...{
      'parentRef': parentRef,
      if (halaqaRef.isNotEmpty) 'halaqaRef': halaqaRef,
    },
  };
}

enum ImportIssueLevel { error, warning }

class ImportIssue {
  final ImportIssueLevel level;
  final int line;
  final String message;

  const ImportIssue(this.level, this.line, this.message);

  bool get isError => level == ImportIssueLevel.error;
}

class ImportPlan {
  /// Valid rows in dependency order (staff, parents, halaqat, students).
  final List<ImportRow> rows;
  final List<ImportIssue> issues;

  const ImportPlan({required this.rows, required this.issues});

  bool get hasErrors => issues.any((i) => i.isError);
  int count(ImportRowKind kind) => rows.where((r) => r.kind == kind).length;
}

/// RFC 4180-style CSV parsing (quotes, escaped quotes, CRLF, BOM).
List<List<String>> parseCsv(String input) {
  final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

String? _clock(String raw) {
  final m = _clockPattern.firstMatch(raw.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

/// "الأحد 16:00-17:00؛ الثلاثاء 16:00-17:00" → slots; throws a message.
List<ImportSlot> parseSchedule(String raw) {
  final slots = <ImportSlot>[];
  for (final part in raw.split(RegExp('[;؛|]'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final m = RegExp(r'^(\S+)\s+(\S+)\s*-\s*(\S+)$').firstMatch(p);
    final day = m == null ? null : _dayLabels[halaqaNameKey(m.group(1))];
    final start = m == null ? null : _clock(m.group(2)!);
    final end = m == null ? null : _clock(m.group(3)!);
    if (day == null || start == null || end == null) {
      throw FormatException('موعد غير مفهوم: "$p"');
    }
    if (end.compareTo(start) <= 0) {
      throw FormatException('وقت النهاية يجب أن يكون بعد البداية: "$p"');
    }
    slots.add(ImportSlot(day, start, end));
  }
  return slots;
}

/// Run label for the audit trail (FNV-1a, four 32-bit lanes; web-safe).
/// Deduplication does not depend on it: the server ledger is keyed by ref.
String importRunId(String content) {
  final lanes = [0x811c9dc5, 0x01000193, 0x050c5d1f, 0x2b5f3e7d];
  for (final b in utf8.encode(content)) {
    for (var i = 0; i < lanes.length; i++) {
      lanes[i] = (((lanes[i] ^ (b + i * 31)) & 0xFFFFFFFF) * 0x01000193) & 0xFFFFFFFF;
    }
  }
  return 'imp_${lanes.map((v) => v.toRadixString(16).padLeft(8, '0')).join()}';
}

const _phase = {
  ImportRowKind.teacher: 0,
  ImportRowKind.supervisor: 0,
  ImportRowKind.assistant: 0,
  ImportRowKind.parent: 0,
  ImportRowKind.halaqa: 1,
  ImportRowKind.student: 2,
};

/// Parses and validates the whole file before anything is created.
ImportPlan validateAcademyImport(String csv) {
  final table = parseCsv(csv);
  final issues = <ImportIssue>[];
  if (table.isEmpty) {
    return const ImportPlan(
      rows: [],
      issues: [ImportIssue(ImportIssueLevel.error, 0, 'الملف فارغ')],
    );
  }
  final header = table.first.map((h) => h.trim().toLowerCase()).toList();
  final missing = ['type', 'ref', 'name'].where((c) => !header.contains(c));
  if (missing.isNotEmpty) {
    return ImportPlan(
      rows: const [],
      issues: [
        ImportIssue(
          ImportIssueLevel.error,
          1,
          'أعمدة ناقصة في الصف الأول: ${missing.join('، ')}. استخدم القالب.',
        ),
      ],
    );
  }
  String cell(List<String> r, String col) {
    final i = header.indexOf(col);
    return i < 0 || i >= r.length ? '' : r[i].trim();
  }

  final parsed = <ImportRow>[];
  final refLines = <String, int>{};
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    final line = i + 1;
    final kind = ImportRowKind.parse(cell(r, 'type'));
    final ref = cell(r, 'ref');
    final name = cell(r, 'name').replaceAll(RegExp(r'\s+'), ' ');
    if (kind == null) {
      issues.add(ImportIssue(ImportIssueLevel.error, line, 'نوع السجل غير معروف: "${cell(r, 'type')}"'));
      continue;
    }
    if (!_refPattern.hasMatch(ref)) {
      issues.add(ImportIssue(ImportIssueLevel.error, line, 'رمز المرجع مفقود أو غير صالح (حروف إنجليزية وأرقام فقط)'));
      continue;
    }
    if (refLines.containsKey(ref)) {
      issues.add(ImportIssue(ImportIssueLevel.error, line, 'الرمز $ref مكرر (السطر ${refLines[ref]})'));
      continue;
    }
    refLines[ref] = line;
    if (name.length < 2) {
      issues.add(ImportIssue(ImportIssueLevel.error, line, 'الاسم مفقود أو قصير جداً ($ref)'));
      continue;
    }
    if (RegExp(r'@|\d{7,}').hasMatch(name)) {
      issues.add(ImportIssue(ImportIssueLevel.error, line, 'الاسم يحتوي بيانات تواصل ($ref)'));
      continue;
    }
    var schedule = const <ImportSlot>[];
    if (kind == ImportRowKind.halaqa) {
      try {
        schedule = parseSchedule(cell(r, 'schedule'));
      } on FormatException catch (e) {
        issues.add(ImportIssue(ImportIssueLevel.error, line, '${e.message} ($ref)'));
        continue;
      }
      if (schedule.isEmpty) {
        issues.add(ImportIssue(ImportIssueLevel.error, line, 'الحلقة $ref بلا موعد'));
        continue;
      }
      final link = cell(r, 'meeting_link');
      if (link.isNotEmpty && !link.startsWith('https://')) {
        issues.add(ImportIssue(ImportIssueLevel.error, line, 'رابط الاجتماع يجب أن يبدأ بـ https:// ($ref)'));
        continue;
      }
    }
    parsed.add(
      ImportRow(
        line: line,
        kind: kind,
        ref: ref,
        name: name,
        teacherRef: cell(r, 'teacher_ref'),
        supervisorRef: cell(r, 'supervisor_ref'),
        assistantRef: cell(r, 'assistant_ref'),
        parentRef: cell(r, 'parent_ref'),
        halaqaRef: cell(r, 'halaqa_ref'),
        schedule: schedule,
        meetingLink: cell(r, 'meeting_link'),
      ),
    );
  }

  final byRef = {for (final r in parsed) r.ref: r};
  final valid = <ImportRow>[];
  final halaqaNames = <String, int>{};
  final personNames = <String, int>{};

  bool reference(ImportRow row, String ref, ImportRowKind expected, String label, {required bool required}) {
    if (ref.isEmpty) {
      if (required) {
        issues.add(ImportIssue(
          ImportIssueLevel.error,
          row.line,
          row.kind == ImportRowKind.student
              ? 'الطالب ${row.ref} بلا ولي أمر'
              : 'الحلقة ${row.ref} بلا معلم',
        ));
      }
      return !required;
    }
    if (refLines.containsKey(ref) && !byRef.containsKey(ref)) {
      issues.add(ImportIssue(ImportIssueLevel.error, row.line, '$label $ref في سطر غير صالح (${row.ref})'));
      return false;
    }
    final target = byRef[ref];
    if (target == null) {
      issues.add(ImportIssue(
        ImportIssueLevel.warning,
        row.line,
        '$label $ref غير موجود في الملف؛ يُقبل فقط إن استُورد سابقاً (${row.ref})',
      ));
      return true;
    }
    if (target.kind != expected) {
      issues.add(ImportIssue(
        ImportIssueLevel.error,
        row.line,
        '$ref ليس ${expected.label} (${row.ref})',
      ));
      return false;
    }
    return true;
  }

  for (final row in parsed) {
    var ok = true;
    switch (row.kind) {
      case ImportRowKind.halaqa:
        ok = reference(row, row.teacherRef, ImportRowKind.teacher, 'المعلم', required: true) &&
            reference(row, row.supervisorRef, ImportRowKind.supervisor, 'المشرف', required: false) &&
            reference(row, row.assistantRef, ImportRowKind.assistant, 'المساعد', required: false);
        final key = halaqaNameKey(row.name);
        if (halaqaNames.containsKey(key)) {
          issues.add(ImportIssue(
            ImportIssueLevel.error,
            row.line,
            'اسم الحلقة "${row.name}" مكرر (السطر ${halaqaNames[key]})',
          ));
          ok = false;
        } else {
          halaqaNames[key] = row.line;
        }
      case ImportRowKind.student:
        ok = reference(row, row.parentRef, ImportRowKind.parent, 'ولي الأمر', required: true) &&
            reference(row, row.halaqaRef, ImportRowKind.halaqa, 'الحلقة', required: false);
      case ImportRowKind.teacher:
      case ImportRowKind.supervisor:
      case ImportRowKind.assistant:
      case ImportRowKind.parent:
        break;
    }
    if (row.kind != ImportRowKind.halaqa) {
      final key = '${row.kind.wire}:${halaqaNameKey(row.name)}';
      final previous = personNames[key];
      if (previous != null) {
        issues.add(ImportIssue(
          ImportIssueLevel.warning,
          row.line,
          'اسم مكرر لنفس النوع (السطر $previous): "${row.name}". تأكد أنهما شخصان مختلفان.',
        ));
      } else {
        personNames[key] = row.line;
      }
    }
    if (ok) valid.add(row);
  }

  int byPhase(ImportRow a, ImportRow b) {
    final p = _phase[a.kind]!.compareTo(_phase[b.kind]!);
    return p != 0 ? p : a.line.compareTo(b.line);
  }

  // Rows depending on a rejected row cannot run either (phase order, so a
  // rejected halaqa also blocks its students).
  final rejected = byRef.keys.toSet().difference(valid.map((r) => r.ref).toSet());
  final runnable = <ImportRow>[];
  for (final row in [...valid]..sort(byPhase)) {
    final deps = [row.teacherRef, row.supervisorRef, row.assistantRef, row.parentRef, row.halaqaRef];
    final blocked = deps.where((d) => d.isNotEmpty && rejected.contains(d)).toList();
    if (blocked.isNotEmpty) {
      issues.add(ImportIssue(
        ImportIssueLevel.error,
        row.line,
        '${row.ref} يعتمد على سجل به خطأ: ${blocked.join('، ')}',
      ));
      rejected.add(row.ref);
      continue;
    }
    runnable.add(row);
  }
  issues.sort((a, b) => a.line.compareTo(b.line));
  return ImportPlan(rows: runnable, issues: issues);
}
