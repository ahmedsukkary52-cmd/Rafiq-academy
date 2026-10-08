import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../domain/entities/mushaf_navigation_index.dart';
import '../../domain/entities/mushaf_position.dart';
import '../../domain/mushaf_page_range.dart';
import '../../domain/quran_juz_labels.dart';
import '../../domain/quran_surah_catalog.dart';
import '../../domain/usecases/load_quran_text_usecase.dart';
import '../../domain/usecases/resolve_mushaf_open_position_usecase.dart';
import '../../domain/usecases/save_mushaf_position_usecase.dart';
import 'mushaf_event.dart';
import 'mushaf_state.dart';

/// Owns Mushaf reading: content, page, selection, last-read (not audio).
@lazySingleton
class MushafBloc extends Bloc<MushafEvent, MushafState> {
  final LoadQuranTextUseCase loadQuranText;
  final ResolveMushafOpenPositionUseCase resolveOpenPosition;
  final SaveMushafPositionUseCase savePosition;

  static const persistDebounce = Duration(milliseconds: 500);

  Timer? _persistDebounce;
  MushafPersistPositionEvent? _pendingPersist;
  (String, MushafPosition)? _lastPersisted;
  String? _lastStudentId;
  int? _preferredSurah;
  bool _forceSurahJump = false;

  MushafBloc({
    required this.loadQuranText,
    required this.resolveOpenPosition,
    required this.savePosition,
  }) : super(const MushafState()) {
    on<InitializeMushafEvent>(_onInitialize);
    on<MushafGoToPageEvent>(_onGoToPage);
    on<MushafGoToSurahEvent>(_onGoToSurah);
    on<MushafGoToJuzEvent>(_onGoToJuz);
    on<MushafResumeLastReadEvent>(_onResumeLastRead);
    on<MushafSelectAyahEvent>(_onSelectAyah);
    on<MushafClearSelectionEvent>(_onClearSelection);
    on<MushafRetryEvent>(_onRetry);
    on<MushafToggleChromeEvent>(_onToggleChrome);
    on<MushafSetNightModeEvent>(_onSetNightMode);
    on<MushafPersistPositionEvent>(_onPersist);
  }

  bool get _isReady =>
      state.status == SectionStatus.loaded && state.quran != null;

  Future<void> _onInitialize(
    InitializeMushafEvent event,
    Emitter<MushafState> emit,
  ) async {
    final studentId = event.studentId.trim();
    _lastStudentId = studentId;
    _preferredSurah = event.preferredSurah;
    _forceSurahJump = event.forceSurahJump;

    // Idempotent: same student already loaded (IndexedStack / double bootstrap).
    if (_isReady && state.studentId == studentId && !_forceSurahJump) {
      return;
    }

    if (state.status == SectionStatus.loading && state.studentId == studentId) {
      return;
    }

    if (studentId != state.studentId) {
      // Previous student's pending write keeps its own captured id.
      _flushPendingPersist();
    }

    emit(
      state.copyWith(
        status: SectionStatus.loading,
        clearError: true,
        studentId: studentId,
        position: MushafPosition.alFatihah,
        clearResume: true,
        clearSelection: true,
      ),
    );

    final textResult = await loadQuranText(const NoParams());
    if (state.studentId != studentId) return;
    final failure = textResult.fold<String?>((f) => f.message, (_) => null);
    if (failure != null) {
      emit(state.copyWith(status: SectionStatus.error, errorMessage: failure));
      return;
    }

    final quran = textResult.getOrElse((_) => throw StateError('quran'));
    final openResult = await resolveOpenPosition(StudentIdParams(studentId));
    if (state.studentId != studentId) return;

    var position = openResult.getOrElse((_) => MushafPosition.alFatihah);
    if (!position.isValid) {
      position = MushafPosition.alFatihah;
    }
    final resume = position;
    _lastPersisted = (studentId, position);

    final navigation = MushafNavigationIndex.fromBundle(quran);

    // Deep-link surah jump only when explicitly forced (optional query).
    final preferred = _preferredSurah;
    if (_forceSurahJump &&
        preferred != null &&
        QuranSurahCatalog.isValidSurah(preferred)) {
      final page = navigation.pageForSurah(preferred);
      if (page != null) {
        position = MushafPosition(
          pageNumber: page,
          surahNumber: preferred,
          ayahNumber: 1,
        );
      }
    }

    emit(
      state.copyWith(
        status: SectionStatus.loaded,
        quran: quran,
        navigation: navigation,
        position: position,
        resumePosition: resume,
        clearSelection: true,
        clearError: true,
      ),
    );
  }

  Future<void> _onGoToPage(
    MushafGoToPageEvent event,
    Emitter<MushafState> emit,
  ) async {
    if (!_isReady) return;
    if (!MushafPageRange.isValidPage(event.pageNumber)) return;
    if (event.pageNumber == state.position.pageNumber) return;

    final pageAyahs = state.quran!.ayahsOnPage(event.pageNumber);
    final anchor = pageAyahs.isNotEmpty ? pageAyahs.first : null;
    final next = MushafPosition(
      pageNumber: event.pageNumber,
      surahNumber: anchor?.surahNumber ?? state.position.surahNumber,
      ayahNumber: anchor?.numberInSurah ?? state.position.ayahNumber,
    );
    _moveTo(next, emit, recordReturn: event.fromNavigation);
  }

  void _onGoToSurah(MushafGoToSurahEvent event, Emitter<MushafState> emit) {
    if (!_isReady) return;
    if (!QuranSurahCatalog.isValidSurah(event.surahNumber)) return;
    final page = state.navigation.pageForSurah(event.surahNumber);
    if (page == null) return;
    _moveTo(
      MushafPosition(
        pageNumber: page,
        surahNumber: event.surahNumber,
        ayahNumber: 1,
      ),
      emit,
      recordReturn: true,
    );
  }

  void _onGoToJuz(MushafGoToJuzEvent event, Emitter<MushafState> emit) {
    if (!_isReady) return;
    if (!QuranJuzLabels.isValidJuz(event.juzNumber)) return;
    final page = state.navigation.pageForJuz(event.juzNumber);
    if (page == null) return;
    final pageAyahs = state.quran!.ayahsOnPage(page);
    if (pageAyahs.isEmpty) return;
    final anchor = pageAyahs.firstWhere(
      (a) => a.juz == event.juzNumber,
      orElse: () => pageAyahs.first,
    );
    _moveTo(
      MushafPosition(
        pageNumber: page,
        surahNumber: anchor.surahNumber,
        ayahNumber: anchor.numberInSurah,
      ),
      emit,
      recordReturn: true,
    );
  }

  void _onResumeLastRead(
    MushafResumeLastReadEvent event,
    Emitter<MushafState> emit,
  ) {
    if (!_isReady) return;
    final resume = state.resumePosition;
    if (resume == null || !resume.isValid) return;
    _moveTo(resume, emit, recordReturn: true);
  }

  void _moveTo(
    MushafPosition next,
    Emitter<MushafState> emit, {
    required bool recordReturn,
  }) {
    if (next == state.position) return;
    final leftPage = next.pageNumber != state.position.pageNumber;
    emit(
      state.copyWith(
        position: next,
        resumePosition: recordReturn && leftPage ? state.position : null,
        clearSelection: true,
      ),
    );
    _schedulePersist(next);
  }

  void _onSelectAyah(MushafSelectAyahEvent event, Emitter<MushafState> emit) {
    final ayah = event.ayah;
    final next = MushafPosition(
      pageNumber: ayah.page,
      surahNumber: ayah.surahNumber,
      ayahNumber: ayah.numberInSurah,
    );
    emit(
      state.copyWith(selectedAyah: ayah, position: next, chromeVisible: true),
    );
    if (_isReady) _schedulePersist(next);
  }

  void _onClearSelection(
    MushafClearSelectionEvent event,
    Emitter<MushafState> emit,
  ) {
    emit(state.copyWith(clearSelection: true));
  }

  Future<void> _onRetry(
    MushafRetryEvent event,
    Emitter<MushafState> emit,
  ) async {
    final id = _lastStudentId ?? state.studentId;
    if (id.isEmpty) return;
    add(
      InitializeMushafEvent(
        studentId: id,
        preferredSurah: _preferredSurah,
        forceSurahJump: _forceSurahJump,
      ),
    );
  }

  void _onToggleChrome(
    MushafToggleChromeEvent event,
    Emitter<MushafState> emit,
  ) {
    emit(state.copyWith(chromeVisible: !state.chromeVisible));
  }

  void _onSetNightMode(
    MushafSetNightModeEvent event,
    Emitter<MushafState> emit,
  ) {
    emit(state.copyWith(isNightMode: event.isNight));
  }

  Future<void> _onPersist(
    MushafPersistPositionEvent event,
    Emitter<MushafState> emit,
  ) async {
    final id = event.studentId.trim();
    if (id.isEmpty) return;
    if (_lastPersisted == (id, event.position)) return;
    _lastPersisted = (id, event.position);
    await savePosition(
      SaveMushafPositionParams(studentId: id, position: event.position),
    );
  }

  void _schedulePersist(MushafPosition position) {
    final id = state.studentId.trim();
    if (id.isEmpty) return;
    _persistDebounce?.cancel();
    _pendingPersist = MushafPersistPositionEvent(
      studentId: id,
      position: position,
    );
    _persistDebounce = Timer(persistDebounce, _flushPendingPersist);
  }

  void _flushPendingPersist() {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    final pending = _pendingPersist;
    _pendingPersist = null;
    if (pending != null && !isClosed) add(pending);
  }

  @override
  Future<void> close() {
    _persistDebounce?.cancel();
    final pending = _pendingPersist;
    _pendingPersist = null;
    if (pending != null &&
        _lastPersisted != (pending.studentId, pending.position)) {
      unawaited(
        savePosition(
          SaveMushafPositionParams(
            studentId: pending.studentId,
            position: pending.position,
          ),
        ),
      );
    }
    return super.close();
  }
}
