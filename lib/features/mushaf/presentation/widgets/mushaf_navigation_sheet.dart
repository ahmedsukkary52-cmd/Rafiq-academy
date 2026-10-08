import 'package:flutter/material.dart';

import '../../domain/entities/mushaf_navigation_index.dart';
import '../../domain/entities/mushaf_position.dart';
import '../../domain/mushaf_navigation_query.dart';
import '../../domain/quran_juz_labels.dart';
import '../../domain/quran_surah_catalog.dart';
import 'mushaf_navigation_tiles.dart';
import 'mushaf_reader_tokens.dart';

/// What the reader chose in the navigation sheet.
sealed class MushafNavigationTarget {
  const MushafNavigationTarget();
}

class MushafNavigateToSurah extends MushafNavigationTarget {
  final int surahNumber;
  const MushafNavigateToSurah(this.surahNumber);
}

class MushafNavigateToJuz extends MushafNavigationTarget {
  final int juzNumber;
  const MushafNavigateToJuz(this.juzNumber);
}

class MushafNavigateToPage extends MushafNavigationTarget {
  final int pageNumber;
  const MushafNavigateToPage(this.pageNumber);
}

class MushafNavigateToLastRead extends MushafNavigationTarget {
  const MushafNavigateToLastRead();
}

/// Opens the reader navigation sheet; resolves with the chosen target or null.
Future<MushafNavigationTarget?> showMushafNavigationSheet({
  required BuildContext context,
  required MushafReaderTokens tokens,
  required MushafNavigationIndex navigation,
  required MushafPosition current,
  MushafPosition? lastRead,
}) {
  return showModalBottomSheet<MushafNavigationTarget>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: tokens.isNight ? 0.5 : 0.28),
    constraints: const BoxConstraints(maxWidth: MushafNavigationSheet.maxWidth),
    builder: (sheetContext) => MushafNavigationSheet(
      tokens: tokens,
      navigation: navigation,
      current: current,
      lastRead: lastRead,
      onSelected: (target) => Navigator.of(sheetContext).pop(target),
    ),
  );
}

class MushafNavigationSheet extends StatefulWidget {
  const MushafNavigationSheet({
    super.key,
    required this.tokens,
    required this.navigation,
    required this.current,
    required this.onSelected,
    this.lastRead,
  });

  static const double maxWidth = 640;

  final MushafReaderTokens tokens;
  final MushafNavigationIndex navigation;
  final MushafPosition current;
  final MushafPosition? lastRead;
  final ValueChanged<MushafNavigationTarget> onSelected;

  @override
  State<MushafNavigationSheet> createState() => _MushafNavigationSheetState();
}

class _MushafNavigationSheetState extends State<MushafNavigationSheet> {
  static const _surahTab = 0;

  final _searchController = TextEditingController();
  int _tab = _surahTab;
  List<MushafSurahEntry> _visibleSurahs = const [];

  @override
  void initState() {
    super.initState();
    _visibleSurahs = widget.navigation.surahs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _visibleSurahs = MushafSurahSearch.filter(
        widget.navigation.surahs,
        query,
      );
    });
  }

  String _digits(int n) => MushafReaderTokens.arabicDigits(n);

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.86;
    final currentJuz = widget.navigation.juzForPage(widget.current.pageNumber);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: tokens.chrome,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: tokens.divider)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _handle(tokens)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      _header(tokens, currentJuz),
                      const SizedBox(height: 14),
                      _lastReadRow(tokens),
                      const SizedBox(height: 14),
                      MushafPageJumpField(
                        tokens: tokens,
                        onSubmit: (page) =>
                            widget.onSelected(MushafNavigateToPage(page)),
                      ),
                      const SizedBox(height: 8),
                      MushafNavTabs(
                        tokens: tokens,
                        labels: const ['السور', 'الأجزاء'],
                        selected: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      const SizedBox(height: 12),
                      if (_tab == _surahTab) ...[
                        MushafSurahSearchField(
                          tokens: tokens,
                          controller: _searchController,
                          onChanged: _onSearch,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: _tab == _surahTab
                      ? _surahList(tokens)
                      : _juzList(tokens, currentJuz),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(MushafReaderTokens tokens) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: tokens.chromeMuted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header(MushafReaderTokens tokens, int? currentJuz) {
    final where = [
      'صفحة ${_digits(widget.current.pageNumber)}',
      if (currentJuz != null) QuranJuzLabels.nameOf(currentJuz),
    ].join(' · ');
    return Row(
      children: [
        Text(
          'التنقّل في المصحف',
          maxLines: 1,
          style: tokens.chromeLabelStyle(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            where,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: tokens
                .chromeLabelStyle(size: 11.5, weight: FontWeight.w500)
                .copyWith(color: tokens.chromeMuted),
          ),
        ),
      ],
    );
  }

  Widget _lastReadRow(MushafReaderTokens tokens) {
    final lastRead = widget.lastRead ?? MushafPosition.alFatihah;
    final surah = QuranSurahCatalog.of(lastRead.surahNumber);
    final isStart = lastRead == MushafPosition.alFatihah;
    return MushafLastReadRow(
      tokens: tokens,
      title: isStart
          ? 'بداية المصحف · سورة ${surah.name}'
          : 'سورة ${surah.name} · الآية ${_digits(lastRead.ayahNumber)}',
      detail: 'صفحة ${_digits(lastRead.pageNumber)}',
      isCurrent: lastRead.pageNumber == widget.current.pageNumber,
      onTap: () => widget.onSelected(const MushafNavigateToLastRead()),
    );
  }

  Widget _surahList(MushafReaderTokens tokens) {
    if (widget.navigation.surahs.isEmpty) {
      return SliverToBoxAdapter(
        child: MushafNavMessage(
          tokens: tokens,
          icon: Icons.menu_book_outlined,
          title: 'فهرس السور غير متاح حالياً',
        ),
      );
    }
    if (_visibleSurahs.isEmpty) {
      return SliverToBoxAdapter(
        child: MushafNavMessage(
          tokens: tokens,
          icon: Icons.search_off_rounded,
          title: 'لا توجد سورة بهذا الاسم',
          subtitle: 'جرّب جزءاً من اسم السورة أو رقمها',
        ),
      );
    }
    final currentSurah = widget.current.surahNumber;
    return SliverFixedExtentList(
      itemExtent: MushafSurahTile.height + 2,
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = _visibleSurahs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: MushafSurahTile(
            key: ValueKey('mushaf-surah-${entry.number}'),
            tokens: tokens,
            entry: entry,
            active: entry.number == currentSurah,
            onTap: () => widget.onSelected(MushafNavigateToSurah(entry.number)),
          ),
        );
      }, childCount: _visibleSurahs.length),
    );
  }

  Widget _juzList(MushafReaderTokens tokens, int? currentJuz) {
    final navigation = widget.navigation;
    if (!navigation.hasJuzData) {
      return SliverToBoxAdapter(
        child: MushafNavMessage(
          tokens: tokens,
          icon: Icons.layers_outlined,
          title: 'بيانات الأجزاء غير متاحة حالياً',
          subtitle: 'يمكنك التنقّل بالسور أو برقم الصفحة',
        ),
      );
    }
    return SliverFixedExtentList(
      itemExtent: MushafJuzTile.height + 2,
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = navigation.juzs[index];
        final surah = navigation.surahForPage(entry.startPage);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: MushafJuzTile(
            key: ValueKey('mushaf-juz-${entry.number}'),
            tokens: tokens,
            entry: entry,
            firstSurahName: surah == null
                ? null
                : QuranSurahCatalog.of(surah).name,
            active: entry.number == currentJuz,
            onTap: () => widget.onSelected(MushafNavigateToJuz(entry.number)),
          ),
        );
      }, childCount: navigation.juzs.length),
    );
  }
}
