import 'dart:collection';
import 'dart:io';

/// The five role modules under `lib/features/`.
const roleModules = {'student', 'teacher', 'supervisor', 'admin', 'parent'};

/// One `import`, `export` or `part` URI found in the directive section of a
/// Dart file. Conditional imports produce one directive per URI.
class DartDirective {
  const DartDirective(this.kind, this.uri, this.line);

  final String kind;
  final String uri;
  final int line;
}

/// Reads the directive section only: scanning stops at the first token that
/// is not a comment, annotation, `library`, `import`, `export` or `part`
/// directive, so code, comments and string literals elsewhere never count.
List<DartDirective> parseDirectives(String source) =>
    _Scanner(source).directives();

/// [source] with comments removed and string literal contents blanked, for
/// identifier searches that must ignore doc comments and text.
String codeWithoutCommentsAndStrings(String source) =>
    _Scanner(source).stripped();

/// Where a project-local directive points.
class ImportEdge {
  const ImportEdge({
    required this.source,
    required this.target,
    required this.uri,
    required this.line,
    required this.kind,
    required this.clamped,
  });

  /// `lib/`-relative, `/`-separated paths.
  final String source;
  final String target;
  final String uri;
  final int line;
  final String kind;

  /// The relative URI climbed above `lib/`; Dart clamps `..` at the package
  /// root, so it still resolves.
  final bool clamped;

  String get key => '$source -> $target';

  @override
  String toString() => '$source:$line -> $target ($kind \'$uri\')';
}

/// Resolves [uri] written in the `lib/`-relative file [from].
///
/// Returns null for external URIs (`dart:`, other packages). Throws
/// [FormatException] for URIs the project cannot resolve statically.
({String target, bool clamped})? resolveProjectUri({
  required String from,
  required String uri,
  required String packageName,
}) {
  final packagePrefix = 'package:$packageName/';
  if (uri.startsWith(packagePrefix)) {
    return (
      target: _normalize(uri.substring(packagePrefix.length).split('/')).path,
      clamped: false,
    );
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(uri)) {
    throw FormatException('Unsupported URI scheme', uri);
  }
  final dir = normalizePath(from).split('/')..removeLast();
  final result = _normalize([...dir, ...uri.split('/')]);
  return (target: result.path, clamped: result.clamped);
}

/// `/`-separated path with `.` and empty segments removed.
String normalizePath(String path) => path
    .replaceAll(r'\', '/')
    .split('/')
    .where((s) => s.isNotEmpty && s != '.')
    .join('/');

({String path, bool clamped}) _normalize(List<String> segments) {
  final out = <String>[];
  var clamped = false;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (out.isEmpty) {
        clamped = true;
      } else {
        out.removeLast();
      }
      continue;
    }
    out.add(segment);
  }
  return (path: out.join('/'), clamped: clamped);
}

/// Module of a `lib/`-relative path: the feature name for `features/<name>/`,
/// `core`, `shared`, or the path itself for top-level files (`main.dart`).
String moduleOf(String path) {
  final parts = path.split('/');
  if (parts.length > 2 && parts.first == 'features') return parts[1];
  if (parts.length > 1) return parts.first;
  return path;
}

bool isRoleFile(String path) =>
    roleModules.contains(moduleOf(path)) && path.startsWith('features/');

/// Every project-local import edge between the Dart files of a `lib/` tree.
class DartImportGraph {
  DartImportGraph._(this.files, this.edges, this.unresolved, this.invalid);

  /// Loads every `.dart` file under [libDir].
  factory DartImportGraph.load(String libDir, {required String packageName}) {
    final root = Directory(libDir);
    final rootPath = normalizePath(root.absolute.path);
    final sources = <String, String>{};
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final abs = normalizePath(entity.absolute.path);
      sources[abs.substring(rootPath.length + 1)] = entity.readAsStringSync();
    }
    return DartImportGraph.fromSources(sources, packageName: packageName);
  }

  /// Builds the graph from `lib/`-relative paths (either separator) to
  /// source text.
  factory DartImportGraph.fromSources(
    Map<String, String> sources, {
    required String packageName,
  }) {
    final normalized = {
      for (final entry in sources.entries)
        normalizePath(entry.key): entry.value,
    };
    final edges = <String, List<ImportEdge>>{};
    final unresolved = <ImportEdge>[];
    final invalid = <String>[];
    for (final entry in normalized.entries) {
      final out = edges[entry.key] = [];
      for (final directive in parseDirectives(entry.value)) {
        ({String target, bool clamped})? resolved;
        try {
          resolved = resolveProjectUri(
            from: entry.key,
            uri: directive.uri,
            packageName: packageName,
          );
        } on FormatException {
          invalid.add('${entry.key}:${directive.line} \'${directive.uri}\'');
          continue;
        }
        if (resolved == null) continue;
        final edge = ImportEdge(
          source: entry.key,
          target: resolved.target,
          uri: directive.uri,
          line: directive.line,
          kind: directive.kind,
          clamped: resolved.clamped,
        );
        if (normalized.containsKey(edge.target)) {
          out.add(edge);
        } else {
          unresolved.add(edge);
        }
      }
    }
    return DartImportGraph._(
      SplayTreeSet.of(normalized.keys),
      edges,
      unresolved,
      invalid,
    );
  }

  final Set<String> files;
  final Map<String, List<ImportEdge>> edges;

  /// Project-local directives whose target file does not exist.
  final List<ImportEdge> unresolved;

  /// Directives whose URI cannot be resolved statically.
  final List<String> invalid;

  Iterable<ImportEdge> get allEdges => edges.values.expand((e) => e);

  Iterable<ImportEdge> importsOf(String file) => edges[file] ?? const [];

  Iterable<ImportEdge> importersOf(String file) =>
      allEdges.where((e) => e.target == file);

  /// Breadth-first closure from [starts]. Files for which [expand] returns
  /// false are reached but not followed. Each file is visited once, so cycles
  /// terminate.
  Closure closure(
    Iterable<String> starts, {
    bool Function(String file) expand = _always,
  }) {
    final parent = <String, ImportEdge?>{};
    final queue = Queue<String>();
    for (final start in starts) {
      final file = normalizePath(start);
      if (parent.containsKey(file)) continue;
      parent[file] = null;
      queue.add(file);
    }
    while (queue.isNotEmpty) {
      final file = queue.removeFirst();
      if (!expand(file)) continue;
      for (final edge in importsOf(file)) {
        if (parent.containsKey(edge.target)) continue;
        parent[edge.target] = edge;
        queue.add(edge.target);
      }
    }
    return Closure._(parent);
  }
}

bool _always(String _) => true;

class Closure {
  Closure._(this._parent);

  final Map<String, ImportEdge?> _parent;

  Set<String> get files => _parent.keys.toSet();

  bool contains(String file) => _parent.containsKey(file);

  /// Edge by which [file] was first reached (null for a start file).
  ImportEdge? reachedBy(String file) => _parent[file];

  /// Import chain from a start file to [file].
  String chainTo(String file) {
    final chain = <String>[file];
    for (var edge = _parent[file]; edge != null; edge = _parent[edge.source]) {
      chain.insert(0, edge.source);
    }
    return chain.join(' -> ');
  }
}

class _Scanner {
  _Scanner(this.src);

  final String src;
  var _i = 0;

  int get _line => '\n'.allMatches(src.substring(0, _i)).length + 1;

  bool _at(String s) => src.startsWith(s, _i);

  bool _isIdent(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F ||
      c == 0x24;

  /// Skips whitespace and comments; true if anything remains.
  bool _skipTrivia() {
    while (_i < src.length) {
      final c = src.codeUnitAt(_i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xFEFF) {
        _i++;
      } else if (_at('//') || (_i == 0 && _at('#!'))) {
        final end = src.indexOf('\n', _i);
        _i = end < 0 ? src.length : end + 1;
      } else if (_at('/*')) {
        _skipBlockComment();
      } else {
        return true;
      }
    }
    return false;
  }

  void _skipBlockComment() {
    var depth = 0;
    while (_i < src.length) {
      if (_at('/*')) {
        depth++;
        _i += 2;
      } else if (_at('*/')) {
        depth--;
        _i += 2;
        if (depth == 0) return;
      } else {
        _i++;
      }
    }
  }

  /// Code inside `$name` / `${...}` of the strings read so far.
  final interpolations = <String>[];

  /// Reads a string literal starting at [_i] and returns its raw content.
  String _readString() {
    var raw = false;
    if (src[_i] == 'r' || src[_i] == 'R') {
      raw = true;
      _i++;
    }
    final quote = src[_i];
    final triple = _at('$quote$quote$quote');
    final close = triple ? '$quote$quote$quote' : quote;
    _i += close.length;
    final start = _i;
    while (_i < src.length) {
      if (!raw && src[_i] == r'\') {
        _i += 2;
        continue;
      }
      if (!raw && _at(r'${')) {
        _i += 2;
        final from = _i;
        _skipInterpolation();
        interpolations.add(src.substring(from, _i - 1));
        continue;
      }
      if (!raw &&
          src[_i] == r'$' &&
          _i + 1 < src.length &&
          _isIdent(src.codeUnitAt(_i + 1))) {
        _i++;
        interpolations.add(_readWord());
        continue;
      }
      if (_at(close)) {
        final value = src.substring(start, _i);
        _i += close.length;
        return value;
      }
      if (!triple && src[_i] == '\n') break;
      _i++;
    }
    throw FormatException('Unterminated string literal', src, start);
  }

  /// Advances past the `}` closing a `${` interpolation, skipping nested
  /// strings, comments and braces.
  void _skipInterpolation() {
    var depth = 1;
    while (_i < src.length) {
      if (_atString()) {
        _readString();
        continue;
      }
      if (_at('//') || _at('/*')) {
        _skipTrivia();
        continue;
      }
      final c = src[_i++];
      if (c == '{') depth++;
      if (c == '}' && --depth == 0) return;
    }
    throw FormatException('Unterminated string interpolation', src, _i);
  }

  bool _atString() {
    if (_i >= src.length) return false;
    final c = src[_i];
    if (c == '\'' || c == '"') return true;
    return (c == 'r' || c == 'R') &&
        _i + 1 < src.length &&
        (src[_i + 1] == '\'' || src[_i + 1] == '"') &&
        (_i == 0 || !_isIdent(src.codeUnitAt(_i - 1)));
  }

  String _readWord() {
    final start = _i;
    while (_i < src.length && _isIdent(src.codeUnitAt(_i))) {
      _i++;
    }
    return src.substring(start, _i);
  }

  void _skipAnnotation() {
    _i++; // '@'
    while (_i < src.length &&
        (_isIdent(src.codeUnitAt(_i)) || src[_i] == '.')) {
      _i++;
    }
    _skipTrivia();
    if (_i < src.length && src[_i] == '(') _skipBalanced();
  }

  void _skipBalanced() {
    var depth = 0;
    while (_i < src.length) {
      if (_atString()) {
        _readString();
        continue;
      }
      if (_at('//') || _at('/*')) {
        _skipTrivia();
        continue;
      }
      final c = src[_i++];
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) return;
    }
  }

  List<DartDirective> directives() {
    final out = <DartDirective>[];
    while (_skipTrivia()) {
      if (src[_i] == '@') {
        _skipAnnotation();
        continue;
      }
      final save = _i;
      final word = _readWord();
      if (word == 'library') {
        _skipToSemicolon(null, null);
      } else if (word == 'import' || word == 'export' || word == 'part') {
        final line = _line;
        _skipTrivia();
        final save2 = _i;
        if (word == 'part' && _readWord() == 'of') {
          _skipToSemicolon(null, null);
          continue;
        }
        _i = save2;
        _skipToSemicolon(out, (uri) => DartDirective(word, uri, line));
      } else {
        _i = save;
        break;
      }
    }
    return out;
  }

  /// Advances past the directive's `;`, collecting string literals at
  /// parenthesis depth zero (the URI and any conditional-import URIs).
  void _skipToSemicolon(
    List<DartDirective>? out,
    DartDirective Function(String uri)? make,
  ) {
    var depth = 0;
    while (_i < src.length) {
      if (_at('//') || _at('/*')) {
        _skipTrivia();
        continue;
      }
      if (_atString()) {
        final value = _readString();
        if (depth == 0 && out != null) out.add(make!(value));
        continue;
      }
      final c = src[_i++];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ';' && depth == 0) return;
    }
  }

  String stripped() {
    final buffer = StringBuffer();
    while (_i < src.length) {
      if (_at('//')) {
        final end = src.indexOf('\n', _i);
        _i = end < 0 ? src.length : end;
      } else if (_at('/*')) {
        _skipBlockComment();
        buffer.write(' ');
      } else if (_atString()) {
        interpolations.clear();
        _readString();
        buffer.write("''");
        for (final code in [...interpolations]) {
          buffer.write(' ${_Scanner(code).stripped()} ');
        }
      } else {
        buffer.write(src[_i++]);
      }
    }
    return buffer.toString();
  }
}
