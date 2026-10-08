import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/mushaf_ayah.dart';
import '../../domain/entities/mushaf_navigation_index.dart';
import '../../domain/entities/mushaf_position.dart';
import '../../domain/entities/quran_text_bundle.dart';

class MushafState extends Equatable {
  final SectionStatus status;
  final String? errorMessage;
  final String studentId;
  final QuranTextBundle? quran;
  final MushafNavigationIndex navigation;
  final MushafPosition position;

  /// "آخر موضع قراءة": the C15 position resolved at open, then the place the
  /// reader left on each explicit navigation jump. Never memorization data.
  final MushafPosition? resumePosition;
  final MushafAyah? selectedAyah;
  final bool chromeVisible;
  final bool isNightMode;

  const MushafState({
    this.status = SectionStatus.initial,
    this.errorMessage,
    this.studentId = '',
    this.quran,
    this.navigation = MushafNavigationIndex.empty,
    this.position = MushafPosition.alFatihah,
    this.resumePosition,
    this.selectedAyah,
    this.chromeVisible = false,
    this.isNightMode = false,
  });

  int get currentPage => position.pageNumber;

  List<MushafAyah> get currentPageAyahs {
    final q = quran;
    if (q == null) return const [];
    return q.ayahsOnPage(position.pageNumber);
  }

  MushafState copyWith({
    SectionStatus? status,
    String? errorMessage,
    bool clearError = false,
    String? studentId,
    QuranTextBundle? quran,
    MushafNavigationIndex? navigation,
    MushafPosition? position,
    MushafPosition? resumePosition,
    bool clearResume = false,
    MushafAyah? selectedAyah,
    bool clearSelection = false,
    bool? chromeVisible,
    bool? isNightMode,
  }) {
    return MushafState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      studentId: studentId ?? this.studentId,
      quran: quran ?? this.quran,
      navigation: navigation ?? this.navigation,
      position: position ?? this.position,
      resumePosition: clearResume
          ? null
          : (resumePosition ?? this.resumePosition),
      selectedAyah: clearSelection ? null : (selectedAyah ?? this.selectedAyah),
      chromeVisible: chromeVisible ?? this.chromeVisible,
      isNightMode: isNightMode ?? this.isNightMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    studentId,
    quran,
    navigation,
    position,
    resumePosition,
    selectedAyah,
    chromeVisible,
    isNightMode,
  ];
}
