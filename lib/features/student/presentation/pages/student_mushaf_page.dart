import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../mushaf/data/datasources/quran_text_remote_datasource.dart';
import '../../../mushaf/domain/entities/mushaf_ayah.dart';
import '../../../mushaf/domain/entities/mushaf_navigation_index.dart';
import '../../../mushaf/domain/entities/mushaf_position.dart';
import '../../../mushaf/domain/entities/quran_text_bundle.dart';
import '../../../mushaf/domain/mushaf_page_range.dart';
import '../../../mushaf/domain/quran_surah_catalog.dart';
import '../../../mushaf/presentation/bloc/mushaf_audio_bloc.dart';
import '../../../mushaf/presentation/bloc/mushaf_audio_event.dart';
import '../../../mushaf/presentation/bloc/mushaf_audio_state.dart';
import '../../../mushaf/presentation/bloc/mushaf_bloc.dart';
import '../../../mushaf/presentation/bloc/mushaf_event.dart';
import '../../../mushaf/presentation/bloc/mushaf_state.dart';
import '../../../mushaf/presentation/widgets/mushaf_audio_bar.dart';
import '../../../mushaf/presentation/widgets/mushaf_navigation_sheet.dart';
import '../../../mushaf/presentation/widgets/mushaf_page_surface.dart';
import '../../../mushaf/presentation/widgets/mushaf_reader_states.dart';
import '../../../mushaf/presentation/widgets/mushaf_reader_tokens.dart';
import '../../../mushaf/presentation/widgets/mushaf_reader_top_chrome.dart';
import 'student_recitation_page.dart';

enum MushafMode { reading, recitation }

class AyahModel {
  final int number;
  final int numberInSurah;
  final String text;
  final int page;
  final int surahNumber;

  const AyahModel({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.page,
    required this.surahNumber,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json, int surahNumber) {
    return AyahModel(
      number: json['number'] as int,
      numberInSurah: json['numberInSurah'] as int,
      text: json['text'] as String,
      page: json['page'] as int,
      surahNumber: surahNumber,
    );
  }
}

class StudentMushafPage extends StatefulWidget {
  /// Optional deep-link surah. Position is owned by [MushafBloc] (D23).
  /// Prefer [MushafReaderHost] for production entry.
  final int? preferredSurah;
  final MushafMode initialMode;

  const StudentMushafPage({
    super.key,
    this.preferredSurah,
    this.initialMode = MushafMode.reading,
  });

  @override
  State<StudentMushafPage> createState() => _StudentMushafPageState();
}

class _StudentMushafPageState extends State<StudentMushafPage> {
  static final String _bismillahText = String.fromCharCodes([
    0x0628,
    0x0650,
    0x0633,
    0x0652,
    0x0645,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0644,
    0x0651,
    0x064e,
    0x0647,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0631,
    0x0651,
    0x064e,
    0x062d,
    0x0652,
    0x0645,
    0x064e,
    0x0670,
    0x0646,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0631,
    0x0651,
    0x064e,
    0x062d,
    0x0650,
    0x064a,
    0x0645,
    0x0650,
  ]);

  late MushafMode _mode;
  int _currentPage = 1; // Current page number
  late final PageController _pageController; // Controller for PageView
  MushafNavigationIndex _navigation = MushafNavigationIndex.empty;

  bool _isDarkMode = false;
  bool _chromeVisible = true;

  /// Recitation-mode panel only; reading mode uses the audio bar.
  bool _showBottomPanel = false;
  double _fontSize = 23;

  bool _isLoadingData = true;
  String _errorLoading = '';
  final List<AyahModel> _ayahs = [];
  final Map<int, int> _ayahIndexByNumber = {};
  List<List<AyahModel>> _groupedByPage =
      []; // Each element is ayahs for one Quran page

  /// Index into [_ayahs]; null until the reader taps an ayah.
  int? _selectedAyahIndex;

  /// Null when the page is pumped without DI (preview / tests).
  MushafAudioBloc? _audio;

  StreamSubscription<Duration>? _recordPositionSub;
  StreamSubscription<Duration?>? _recordDurationSub;
  StreamSubscription<PlayerState>? _recordPlayerStateSub;

  AudioRecorder? _audioRecorderInstance;
  bool _isRecording = false;
  String? _recordedFilePath;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  bool _hasRecorded = false;
  final ValueNotifier<bool> _isPlayingRecording = ValueNotifier(false);
  AudioPlayer? _recordingPlayerInstance;
  final ValueNotifier<Duration> _recordPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _recordDuration = ValueNotifier(Duration.zero);

  final List<TapGestureRecognizer> _ayahRecognizers = [];

  /// Surah of the first ayah on the visible page.
  QuranSurahInfo get _meta =>
      QuranSurahCatalog.of(_navigation.surahForPage(_currentPage) ?? 1);

  AyahModel? get _selectedAyah {
    final index = _selectedAyahIndex;
    if (index == null || index < 0 || index >= _ayahs.length) return null;
    return _ayahs[index];
  }

  AudioRecorder get _audioRecorder =>
      _audioRecorderInstance ??= AudioRecorder();

  AudioPlayer get _recordingPlayer {
    final existing = _recordingPlayerInstance;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _recordPositionSub = player.positionStream.listen((pos) {
      _recordPosition.value = pos;
    });
    _recordDurationSub = player.durationStream.listen((dur) {
      _recordDuration.value = dur ?? Duration.zero;
    });
    _recordPlayerStateSub = player.playerStateStream.listen((state) {
      _isPlayingRecording.value = state.playing;
    });
    return _recordingPlayerInstance = player;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _pageController = PageController(initialPage: 0);
    try {
      _audio = context.read<MushafAudioBloc>();
    } catch (_) {
      _audio = null;
    }
    _restoreNightPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInitialized());
  }

  Future<void> _restoreNightPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final night = prefs.getBool(kMushafNightModePrefsKey) ?? false;
    if (!mounted) return;
    setState(() => _isDarkMode = night);
    _syncNightToBloc(night);
  }

  void _syncNightToBloc(bool isNight) {
    try {
      context.read<MushafBloc>().add(MushafSetNightModeEvent(isNight));
    } catch (_) {}
  }

  Future<void> _setNightMode(bool isNight) async {
    setState(() => _isDarkMode = isNight);
    _syncNightToBloc(isNight);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMushafNightModePrefsKey, isNight);
  }

  void _ensureInitialized() {
    if (!mounted) return;
    MushafBloc? mushaf;
    try {
      mushaf = context.read<MushafBloc>();
    } catch (_) {
      mushaf = null;
    }
    if (mushaf != null) {
      // Host ([MushafReaderHost]) owns InitializeMushafEvent.
      if (mushaf.state.status == SectionStatus.loaded &&
          mushaf.state.quran != null) {
        _hydrateFromBloc(mushaf.state);
      }
      return;
    }
    // Fallback (preview without DI): load text only, start Al-Fatihah.
    _loadSurahDataLegacyAlFatihah();
  }

  void _hydrateFromBloc(MushafState state) {
    final quran = state.quran;
    if (quran == null) return;
    _applyBundle(quran, state.navigation);
    _isLoadingData = false;
    _errorLoading = '';
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPage(state.position.pageNumber);
    });
  }

  void _applyBundle(QuranTextBundle quran, MushafNavigationIndex navigation) {
    _navigation = navigation;
    _ayahs
      ..clear()
      ..addAll(quran.ayahs.map(_ayahFromEntity));
    _groupedByPage = quran.pagesByIndex
        .map((page) => page.map(_ayahFromEntity).toList())
        .toList();
    _ayahIndexByNumber
      ..clear()
      ..addEntries([
        for (var i = 0; i < _ayahs.length; i++) MapEntry(_ayahs[i].number, i),
      ]);
    _rebuildAyahRecognizers();
  }

  AyahModel _ayahFromEntity(MushafAyah a) => AyahModel(
    number: a.globalNumber,
    numberInSurah: a.numberInSurah,
    text: a.text,
    page: a.page,
    surahNumber: a.surahNumber,
  );

  Future<void> _loadSurahDataLegacyAlFatihah() async {
    // Preview-only path: same network/cache load, always open Al-Fatihah.
    await _loadSurahData(forceAlFatihah: true);
  }

  Future<void> _loadSurahData({bool forceAlFatihah = true}) async {
    setState(() {
      _isLoadingData = true;
      _errorLoading = '';
      _selectedAyahIndex = null;
    });

    const cacheKey = 'cached_entire_quran';
    final prefs = await SharedPreferences.getInstance();
    String? responseBody;

    if (prefs.containsKey(cacheKey)) {
      responseBody = prefs.getString(cacheKey);
    }

    if (responseBody == null) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        final request = await client.getUrl(
          Uri.parse('https://api.alquran.cloud/v1/quran/quran-uthmani'),
        );
        final response = await request.close();

        if (response.statusCode == 200) {
          responseBody = await response.transform(utf8.decoder).join();
          await prefs.setString(cacheKey, responseBody);
        } else {
          throw HttpException('HTTP ${response.statusCode}');
        }
        client.close();
      } catch (e) {
        debugPrint('Quran API error: $e');
        if (mounted) {
          setState(() {
            _errorLoading = 'تعذر تحميل المصحف. يرجى المحاولة مجدداً.';
            _isLoadingData = false;
          });
        }
        return;
      }
    }

    _parseSurahResponse(responseBody);
    if (mounted) setState(() => _isLoadingData = false);

    // D23: preview/legacy path always opens Al-Fatihah (never Surah 67).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPage(forceAlFatihah ? 1 : 1);
    });
  }

  void _notifyPageChanged(int page) {
    _maybeMushafBloc()?.add(MushafGoToPageEvent(page));
  }

  void _parseSurahResponse(String jsonBody) {
    final bundle = QuranTextRemoteDatasourceImpl.parseBundle(jsonBody);
    _applyBundle(bundle, MushafNavigationIndex.fromBundle(bundle));
  }

  void _rebuildAyahRecognizers() {
    for (final r in _ayahRecognizers) {
      r.dispose();
    }
    _ayahRecognizers.clear();
    for (var i = 0; i < _ayahs.length; i++) {
      final recognizer = TapGestureRecognizer();
      final index = i;
      recognizer.onTap = () => _selectAyah(index);
      _ayahRecognizers.add(recognizer);
    }
  }

  String _getAyahDisplayText(AyahModel ayah) {
    if (ayah.numberInSurah != 1) {
      return ayah.text;
    }
    // Don't remove Bismillah from Surah Al-Fatiha!
    if (ayah.surahNumber == 1) {
      return ayah.text;
    }
    var text = ayah.text;

    // Build Bismillah from the EXACT character codes from your log!
    final bismillah = String.fromCharCodes([
      0x0628,
      0x0650,
      0x0633,
      0x0652,
      0x0645,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0644,
      0x0651,
      0x064e,
      0x0647,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0631,
      0x0651,
      0x064e,
      0x062d,
      0x0652,
      0x0645,
      0x064e,
      0x0670,
      0x0646,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0631,
      0x0651,
      0x064e,
      0x062d,
      0x0650,
      0x064a,
      0x0645,
      0x0650,
    ]);

    // Try to remove it
    if (text.startsWith(bismillah)) {
      text = text.substring(bismillah.length).trim();
    } else {
      final trimmedText = text.trimLeft();
      if (trimmedText.startsWith(bismillah)) {
        text = trimmedText.substring(bismillah.length).trim();
      }
    }
    return text;
  }

  void _jumpToPage(int pageNumber) {
    // Find page index in _groupedByPage
    final pageIndex = _groupedByPage.indexWhere(
      (page) => page.first.page == pageNumber,
    );
    if (pageIndex == -1) return;
    // Post-frame callers may run after dispose or before the PageView mounts.
    if (!mounted || !_pageController.hasClients) return;
    _pageController.jumpToPage(pageIndex);
  }

  MushafBloc? _maybeMushafBloc() {
    try {
      return context.read<MushafBloc>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNavigation() async {
    if (_groupedByPage.isEmpty) return;
    final mushaf = _maybeMushafBloc();
    final state = mushaf?.state;
    final current = state != null && state.status == SectionStatus.loaded
        ? state.position
        : MushafPosition(
            pageNumber: _currentPage,
            surahNumber: _meta.number,
            ayahNumber: 1,
          );

    final target = await showMushafNavigationSheet(
      context: context,
      tokens: MushafReaderTokens.of(isNight: _isDarkMode),
      navigation: _navigation,
      current: current,
      lastRead: state?.resumePosition,
    );
    if (target == null || !mounted) return;

    if (mushaf != null) {
      mushaf.add(switch (target) {
        MushafNavigateToSurah(:final surahNumber) => MushafGoToSurahEvent(
          surahNumber,
        ),
        MushafNavigateToJuz(:final juzNumber) => MushafGoToJuzEvent(juzNumber),
        MushafNavigateToPage(:final pageNumber) => MushafGoToPageEvent(
          pageNumber,
          fromNavigation: true,
        ),
        MushafNavigateToLastRead() => const MushafResumeLastReadEvent(),
      });
      return;
    }

    final page = switch (target) {
      MushafNavigateToSurah(:final surahNumber) => _navigation.pageForSurah(
        surahNumber,
      ),
      MushafNavigateToJuz(:final juzNumber) => _navigation.pageForJuz(
        juzNumber,
      ),
      MushafNavigateToPage(:final pageNumber) => pageNumber,
      MushafNavigateToLastRead() => MushafPageRange.minPage,
    };
    if (page != null) _jumpToPage(page);
  }

  /// Selecting never touches the network; audio for another ayah stops.
  /// With [play], the ayah starts immediately (bar previous / next).
  void _selectAyah(int index, {bool play = false}) {
    if (index < 0 || index >= _ayahs.length) return;
    final ayah = _ayahs[index];
    final changed = index != _selectedAyahIndex;
    // Skipping no-op setState keeps play / pause from rebuilding the pages.
    if (changed || !_chromeVisible || !_showBottomPanel) {
      setState(() {
        _selectedAyahIndex = index;
        _chromeVisible = true;
        _showBottomPanel = true;
      });
    }
    final mushaf = _maybeMushafBloc();
    final quranAyahs = mushaf?.state.quran?.ayahs;
    if (changed &&
        mushaf != null &&
        quranAyahs != null &&
        index < quranAyahs.length) {
      mushaf.add(MushafSelectAyahEvent(quranAyahs[index]));
    }
    _audio?.add(
      play
          ? MushafAudioPlayAyahEvent(
              surahNumber: ayah.surahNumber,
              ayahNumberInSurah: ayah.numberInSurah,
            )
          : MushafAudioSetTargetEvent(
              surahNumber: ayah.surahNumber,
              ayahNumberInSurah: ayah.numberInSurah,
            ),
    );
  }

  /// First ayah of the visible page — the play target when nothing is
  /// selected yet.
  int? _firstAyahIndexOnCurrentPage() {
    for (final page in _groupedByPage) {
      if (page.first.page == _currentPage) {
        return _ayahIndexByNumber[page.first.number];
      }
    }
    return null;
  }

  void _onAudioPrimary(MushafAudioState audioState) {
    final audio = _audio;
    if (audio == null) return;
    if (audioState.isLoading || audioState.isPlaying) {
      // Pausing while loading cancels the load.
      audio.add(const MushafAudioPauseEvent());
      return;
    }
    final index = _selectedAyahIndex ?? _firstAyahIndexOnCurrentPage();
    if (index == null) return;
    _selectAyah(index, play: true);
  }

  void _stepAyah(int delta) {
    final current = _selectedAyahIndex ?? _firstAyahIndexOnCurrentPage();
    if (current == null) return;
    _selectAyah(current + delta, play: true);
  }

  void _closeAudio() {
    _audio?.add(const MushafAudioStopEvent(clearTarget: true));
    _maybeMushafBloc()?.add(const MushafClearSelectionEvent());
    setState(() => _selectedAyahIndex = null);
  }

  void _openAudioOptions(MushafReaderTokens tokens, MushafAudioState state) {
    final audio = _audio;
    if (audio == null) return;
    showMushafAudioOptionsSheet(
      context: context,
      tokens: tokens,
      selectedReciterId: state.reciter.id,
      isLooping: state.isLooping,
      onSelectReciter: (id) => audio.add(MushafAudioSelectReciterEvent(id)),
      onLoopChanged: (_) => audio.add(const MushafAudioToggleLoopEvent()),
    );
  }

  void _onScreenTap() {
    setState(() {
      _chromeVisible = !_chromeVisible;
      _showBottomPanel = _chromeVisible;
    });
  }

  Future<void> _startRecording() async {
    try {
      final currentAyah =
          _selectedAyah ??
          _ayahs.elementAtOrNull(_firstAyahIndexOnCurrentPage() ?? -1);
      if (currentAyah == null) return;
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/recitation_${currentAyah.surahNumber}_${currentAyah.numberInSurah}_${DateTime.now().millisecondsSinceEpoch}.m4a';

        setState(() {
          _recordedFilePath = path;
          _isRecording = true;
          _recordDurationSeconds = 0;
          _hasRecorded = false;
        });

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordDurationSeconds++);
          }
        });
      }
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'فشل بدء تسجيل الصوت');
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
      _hasRecorded = path != null;
    });
    if (path != null) {
      await _recordingPlayer.setFilePath(path);
    }
  }

  void _togglePlayRecording() {
    if (_isPlayingRecording.value) {
      _recordingPlayer.pause();
    } else {
      _recordingPlayer.play();
    }
  }

  void _submitRecitation() {
    if (_recordedFilePath == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفع التسجيل', textAlign: TextAlign.right),
        content: const Text(
          'رفع التسجيل غير متاح حالياً حتى يتم تفعيل خدمة رفع الملفات.',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _toArabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  String _inlineVerseMarker(int n) => '\uFD3F${_toArabicDigits(n)}\uFD3E';

  @override
  void dispose() {
    _pageController.dispose();
    for (final r in _ayahRecognizers) {
      r.dispose();
    }
    // The audio bloc is an app singleton; leaving the reader silences it.
    final audio = _audio;
    if (audio != null && !audio.isClosed) {
      audio.add(const MushafAudioStopEvent(clearTarget: true));
    }
    _recordPositionSub?.cancel();
    _recordDurationSub?.cancel();
    _recordPlayerStateSub?.cancel();
    _recordingPlayerInstance?.dispose();
    _audioRecorderInstance?.dispose();
    _recordTimer?.cancel();
    _isPlayingRecording.dispose();
    _recordPosition.dispose();
    _recordDuration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = MushafReaderTokens.of(isNight: _isDarkMode);
    final canPop = Navigator.canPop(context);

    Widget reader = Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: tokens.canvas,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _onScreenTap,
                behavior: HitTestBehavior.translucent,
                child: _buildAyahsBody(tokens),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MushafReaderTopChrome(
                tokens: tokens,
                surahName: _meta.name,
                pageNumber: _currentPage,
                visible: _chromeVisible,
                onBack: canPop ? () => Navigator.pop(context) : null,
                onToggleNight: () => _setNightMode(!_isDarkMode),
                onOpenNavigation: _openNavigation,
                onOpenSettings: () =>
                    _showFontSizeSheet(tokens.chrome, tokens.chromeInk),
                onOpenRecitation: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentRecitationPage(
                        surahName: _meta.name,
                        pageNumber: _currentPage,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _mode == MushafMode.recitation
                  ? _bottomSlot(
                      visible: _chromeVisible && _showBottomPanel,
                      child: _buildRecordingPanel(
                        tokens.chrome,
                        tokens.chromeInk,
                      ),
                    )
                  : _buildAudioBarSlot(tokens),
            ),
          ],
        ),
      ),
    );

    MushafBloc? mushaf;
    try {
      mushaf = context.read<MushafBloc>();
    } catch (_) {
      mushaf = null;
    }
    if (mushaf == null) return reader;

    return BlocListener<MushafBloc, MushafState>(
      listenWhen: (prev, next) =>
          prev.status != next.status ||
          prev.quran != next.quran ||
          prev.position.pageNumber != next.position.pageNumber ||
          prev.isNightMode != next.isNightMode,
      listener: (context, state) {
        if (state.isNightMode != _isDarkMode) {
          setState(() => _isDarkMode = state.isNightMode);
        }
        if (state.status == SectionStatus.loaded && state.quran != null) {
          final needsFullHydrate =
              _groupedByPage.isEmpty ||
              _ayahs.length != state.quran!.ayahs.length;
          if (needsFullHydrate) {
            _hydrateFromBloc(state);
          } else if (_currentPage != state.position.pageNumber) {
            _jumpToPage(state.position.pageNumber);
          }
        } else if (state.status == SectionStatus.error) {
          setState(() {
            _isLoadingData = false;
            _errorLoading = state.errorMessage ?? 'تعذر تحميل المصحف';
          });
        } else if (state.status == SectionStatus.loading && _ayahs.isEmpty) {
          setState(() {
            _isLoadingData = true;
            _errorLoading = '';
          });
        }
      },
      child: reader,
    );
  }

  Widget _buildAyahsBody(MushafReaderTokens tokens) {
    if (_isLoadingData) {
      return MushafReaderLoading(tokens: tokens);
    }

    if (_errorLoading.isNotEmpty && _ayahs.isEmpty) {
      return MushafReaderError(
        tokens: tokens,
        message: _errorLoading,
        onRetry: () {
          MushafBloc? mushaf;
          try {
            mushaf = context.read<MushafBloc>();
          } catch (_) {
            mushaf = null;
          }
          if (mushaf != null) {
            mushaf.add(const MushafRetryEvent());
            setState(() {
              _isLoadingData = true;
              _errorLoading = '';
            });
          } else {
            _loadSurahData(forceAlFatihah: true);
          }
        },
      );
    }

    if (_groupedByPage.isEmpty) {
      return ColoredBox(color: tokens.canvas);
    }

    return PageView.builder(
      controller: _pageController,
      physics: const PageScrollPhysics(),
      itemCount: _groupedByPage.length,
      onPageChanged: (pageIndex) {
        final pageNumber = _groupedByPage[pageIndex].first.page;
        setState(() {
          _currentPage = pageNumber;
        });
        _notifyPageChanged(pageNumber);
      },
      itemBuilder: (context, pageIndex) {
        final pageAyahs = _groupedByPage[pageIndex];
        final pageNumber = pageAyahs.first.page;
        return MushafPageSurface(
          tokens: tokens,
          pageNumber: pageNumber,
          // The audio bar can only show while an ayah is selected.
          bottomInset: _mode == MushafMode.reading && _selectedAyahIndex != null
              ? 112
              : 0,
          child: _buildMushafFlowText(tokens, pageAyahs),
        );
      },
    );
  }

  Widget _buildMushafFlowText(
    MushafReaderTokens tokens,
    List<AyahModel> pageAyahs,
  ) {
    final highlightBg = tokens.selection;
    final baseStyle = tokens.bodyStyle(fontSize: _fontSize);

    final children = <Widget>[];
    final allSpans = <InlineSpan>[];

    for (final ayah in pageAyahs) {
      // If this is the first ayah of a surah, add surah header and maybe Bismillah
      if (ayah.numberInSurah == 1) {
        // First, add any previous spans as a RichText
        if (allSpans.isNotEmpty) {
          children.add(
            RichText(
              text: TextSpan(style: baseStyle, children: List.from(allSpans)),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
          allSpans.clear();
        }

        final surahNum = ayah.surahNumber;
        final surahMeta = QuranSurahCatalog.of(surahNum);
        children.add(
          MushafSurahHeader(
            tokens: tokens,
            surahName: surahMeta.name,
            surahNumber: surahNum,
            surahType: surahMeta.revelationLabel,
          ),
        );

        // Show standalone Bismillah if not surah 1 or 9
        if (surahNum != 1 && surahNum != 9) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _bismillahText,
                textAlign: TextAlign.center,
                style: tokens.basmalaStyle(fontSize: _fontSize),
              ),
            ),
          );
        }
      }

      // Build the ayah text
      final originalIndex = _ayahIndexByNumber[ayah.number] ?? -1;
      final isSelected = originalIndex == _selectedAyahIndex;
      final displayText = _getAyahDisplayText(ayah);

      allSpans.add(
        TextSpan(
          text: ' $displayText ',
          style: baseStyle.copyWith(
            color: tokens.ink,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            backgroundColor: isSelected ? highlightBg : null,
          ),
          recognizer: _ayahRecognizers.length > originalIndex
              ? _ayahRecognizers[originalIndex]
              : null,
        ),
      );
      allSpans.add(
        TextSpan(
          text: _inlineVerseMarker(ayah.numberInSurah),
          style: baseStyle.copyWith(
            fontSize: _fontSize * 0.7,
            color: isSelected ? tokens.accent : tokens.ayahMarker,
            fontWeight: FontWeight.w600,
            backgroundColor: isSelected ? highlightBg : null,
          ),
          recognizer: _ayahRecognizers.length > originalIndex
              ? _ayahRecognizers[originalIndex]
              : null,
        ),
      );
    }

    // Add remaining spans
    if (allSpans.isNotEmpty) {
      children.add(
        RichText(
          text: TextSpan(style: baseStyle, children: List.from(allSpans)),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _bottomSlot({required bool visible, required Widget child}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.05),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }

  /// Scoped rebuilds: audio state changes never rebuild the PageView.
  Widget _buildAudioBarSlot(MushafReaderTokens tokens) {
    final audio = _audio;
    if (audio == null) return const SizedBox.shrink();
    return BlocBuilder<MushafAudioBloc, MushafAudioState>(
      bloc: audio,
      builder: (context, state) {
        final surah = state.surahNumber;
        final ayah = state.ayahNumberInSurah;
        // Shown for a selected ayah while chrome is up; audible playback keeps
        // it visible when the reader hides chrome.
        final visible =
            surah != null &&
            ayah != null &&
            (_chromeVisible || state.isPlaying || state.isLoading);
        final current = _selectedAyahIndex ?? _firstAyahIndexOnCurrentPage();
        return _bottomSlot(
          visible: visible,
          child: surah == null || ayah == null
              ? const SizedBox.shrink()
              : MushafAudioBar(
                  tokens: tokens,
                  state: state,
                  surahName: QuranSurahCatalog.of(surah).name,
                  ayahNumber: ayah,
                  positionStream: audio.positionStream,
                  durationStream: audio.durationStream,
                  onPrimary: () => _onAudioPrimary(state),
                  onOptions: () => _openAudioOptions(tokens, state),
                  onClose: _closeAudio,
                  onPrevious: current != null && current > 0
                      ? () => _stepAyah(-1)
                      : null,
                  onNext: current != null && current < _ayahs.length - 1
                      ? () => _stepAyah(1)
                      : null,
                ),
        );
      },
    );
  }

  void _showFontSizeSheet(Color surfaceColor, Color textColor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حجم خط المصحف',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.font_download_outlined, size: 14),
                  Expanded(
                    child: Slider(
                      activeColor: AppColors.primary,
                      value: _fontSize,
                      min: 16,
                      max: 36,
                      onChanged: (val) {
                        setModalState(() => _fontSize = val);
                        setState(() => _fontSize = val);
                      },
                    ),
                  ),
                  const Icon(Icons.font_download, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingPanel(Color surfaceColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedAyah == null
                  ? 'وضع التسميع — ${_meta.name}'
                  : 'وضع التسميع — ${QuranSurahCatalog.of(_selectedAyah!.surahNumber).name} · الآية ${_toArabicDigits(_selectedAyah!.numberInSurah)}',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRecording) ...[
              const Text(
                'جاري تسجيل صوتك الآن...',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatSecondsMmSs(_recordDurationSeconds),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 36),
                ),
              ),
            ] else if (_hasRecorded) ...[
              const Text(
                'تلاوتك المسجلة:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingRecording,
                    builder: (context, playing, _) {
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: _togglePlayRecording,
                      );
                    },
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _recordPosition,
                        _recordDuration,
                      ]),
                      builder: (context, _) {
                        final position = _recordPosition.value;
                        final duration = _recordDuration.value;
                        return Slider(
                          activeColor: AppColors.primary,
                          value: position.inMilliseconds
                              .clamp(
                                0,
                                duration.inMilliseconds > 0
                                    ? duration.inMilliseconds
                                    : 1,
                              )
                              .toDouble(),
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                          onChanged: (val) {
                            _recordingPlayer.seek(
                              Duration(milliseconds: val.toInt()),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _recordDuration,
                    builder: (context, duration, _) {
                      return Text(
                        formatDurationMmSs(duration),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'رفع التسجيل',
                      onPressed: _submitRecitation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                    onPressed: _startRecording,
                    child: const Text(
                      'إعادة التسجيل',
                      style: TextStyle(fontFamily: 'NotoNaskhArabic'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'انقر للبدء بتسجيل تلاوتك للآية المحددة:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 36),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
