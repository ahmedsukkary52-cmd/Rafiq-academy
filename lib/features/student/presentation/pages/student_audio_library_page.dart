import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../audio_library/domain/entities/audio_entities.dart';
import '../../../audio_library/presentation/bloc/audio_bloc.dart';
import '../../../audio_library/presentation/bloc/audio_event.dart';
import '../../../audio_library/presentation/bloc/audio_state.dart';
import '../../../audio_library/presentation/pages/all_reciters_page.dart';
import '../../../audio_library/presentation/widgets/audio_player_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

@injectable
class StudentAudioLibraryPage extends StatelessWidget {
  const StudentAudioLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AudioLibraryBloc>(
      create: (_) => sl<AudioLibraryBloc>()..add(const LoadAudioLibraryEvent()),
      child: const _AudioLibraryView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main View
// ─────────────────────────────────────────────────────────────────────────────

class _AudioLibraryView extends StatefulWidget {
  const _AudioLibraryView();

  @override
  State<_AudioLibraryView> createState() => _AudioLibraryViewState();
}

class _AudioLibraryViewState extends State<_AudioLibraryView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            _AudioLibraryHeader(searchCtrl: _searchCtrl),

            // ── Reciters bar ──────────────────────────────────────────
            const _RecitersBar(),

            // ── Surah list ────────────────────────────────────────────
            const Expanded(child: _SurahList()),

            // ── Mini player ───────────────────────────────────────────
            const AudioPlayerWidget(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _AudioLibraryHeader extends StatelessWidget {
  final TextEditingController searchCtrl;

  const _AudioLibraryHeader({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF2A2A4E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            children: [
              // back button
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مكتبة الصوتيات',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    BlocBuilder<AudioLibraryBloc, AudioLibraryState>(
                      buildWhen: (p, c) =>
                          p.filteredSurahAudios.length !=
                              c.filteredSurahAudios.length ||
                          p.selectedReciterId != c.selectedReciterId,
                      builder: (_, state) {
                        final count = state.filteredSurahAudios.length;
                        return Text(
                          '$count سورة متاحة',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2DC4B2), Color(0xFF1FA99A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search field
          _SearchBar(controller: searchCtrl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'NotoNaskhArabic',
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن سورة...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontFamily: 'NotoNaskhArabic',
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.6),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) => val.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      context.read<AudioLibraryBloc>().add(
                        const SearchAudioLibraryEvent(''),
                      );
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 18,
                    ),
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (v) =>
            context.read<AudioLibraryBloc>().add(SearchAudioLibraryEvent(v)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciters Bar  ← الشريط الجديد للشيوخ
// ─────────────────────────────────────────────────────────────────────────────

class _RecitersBar extends StatelessWidget {
  const _RecitersBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'اختر القارئ',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final bloc = context.read<AudioLibraryBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: const AllRecitersPage(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'عرض الكل',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 88,
            child: BlocBuilder<AudioLibraryBloc, AudioLibraryState>(
              buildWhen: (p, c) =>
                  p.allReciters != c.allReciters ||
                  p.favoriteReciters != c.favoriteReciters ||
                  p.recentReciterIds != c.recentReciterIds ||
                  p.selectedReciterId != c.selectedReciterId ||
                  p.recitersStatus != c.recitersStatus,
              builder: (context, state) {
                if (state.recitersStatus == SectionStatus.loading) {
                  return const _RecitersShimmer();
                }
                final reciters = state.homeReciters;
                if (reciters.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا يوجد قراء',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'NotoNaskhArabic',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: reciters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final reciter = reciters[index];
                    final isSelected = state.selectedReciterId == reciter.id;
                    return _ReciterChip(
                      reciter: reciter,
                      isSelected: isSelected,
                      onTap: () {
                        context.read<AudioLibraryBloc>().add(
                          SelectReciterEvent(isSelected ? null : reciter.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // فاصل
          Divider(height: 1, color: Colors.white.withOpacity(0.08)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ReciterChip extends StatelessWidget {
  final ReciterEntity reciter;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReciterChip({
    required this.reciter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2DC4B2), Color(0xFF1FA99A)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.15),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReciterAvatar(reciter: reciter, isSelected: isSelected),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reciter.name,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reciter.recitationStyle,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: isSelected
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciter Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _ReciterAvatar extends StatelessWidget {
  final ReciterEntity reciter;
  final bool isSelected;

  const _ReciterAvatar({required this.reciter, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final initials = reciter.name.isNotEmpty
        ? reciter.name.trim().split(' ').take(2).map((w) => w[0]).join()
        : '؟';

    final hasImage = reciter.imageUrl != null && reciter.imageUrl!.isNotEmpty;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? Colors.white.withOpacity(0.25)
            : Colors.white.withOpacity(0.1),
        border: Border.all(
          color: isSelected ? Colors.white54 : Colors.white24,
          width: 1.2,
        ),
      ),
      child: hasImage
          ? ClipOval(
              child: Image.network(
                reciter.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsText(initials),
              ),
            )
          : Center(child: _InitialsText(initials)),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String text;

  const _InitialsText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        fontFamily: 'NotoNaskhArabic',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciters Shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _RecitersShimmer extends StatefulWidget {
  const _RecitersShimmer();

  @override
  State<_RecitersShimmer> createState() => _RecitersShimmerState();
}

class _RecitersShimmerState extends State<_RecitersShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      builder: (_, child) {
        return Opacity(opacity: 0.06 + 0.12 * _anim.value, child: child);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah List
// ─────────────────────────────────────────────────────────────────────────────

class _SurahList extends StatelessWidget {
  const _SurahList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioLibraryBloc, AudioLibraryState>(
      buildWhen: (p, c) =>
          p.surahAudios != c.surahAudios ||
          p.filteredSurahAudios.length != c.filteredSurahAudios.length ||
          p.selectedReciterId != c.selectedReciterId ||
          p.searchQuery != c.searchQuery ||
          p.surahAudiosStatus != c.surahAudiosStatus ||
          p.selectedSurah != c.selectedSurah ||
          p.isPlaying != c.isPlaying,
      builder: (context, state) {
        if (state.surahAudiosStatus == SectionStatus.loading) {
          return const _SurahsShimmer();
        }

        final surahs = state.filteredSurahAudios;

        if (surahs.isEmpty) {
          return _EmptyState(
            hasFilter:
                state.selectedReciterId != null || state.searchQuery.isNotEmpty,
          );
        }

        return Column(
          children: [
            // Section header
            _SurahsSectionHeader(
              count: surahs.length,
              reciterName: state.selectedReciter?.name,
            ),

            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  final isSelected = state.selectedSurah?.id == surah.id;
                  final isPlaying = isSelected && state.isPlaying;
                  return _SurahTile(
                    surah: surah,
                    isSelected: isSelected,
                    isPlaying: isPlaying,
                    onTap: () => context.read<AudioLibraryBloc>().add(
                      SelectSurahAudioEvent(surah),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surahs Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SurahsSectionHeader extends StatelessWidget {
  final int count;
  final String? reciterName;

  const _SurahsSectionHeader({required this.count, this.reciterName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            reciterName != null ? 'تلاوات $reciterName' : 'جميع التلاوات',
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count سورة',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SurahTile extends StatelessWidget {
  final SurahAudioEntity surah;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SurahTile({
    required this.surah,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
  });

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '--:--';
    return formatDurationMmSs(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _PlayButton(isSelected: isSelected, isPlaying: isPlaying),
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${surah.surahNumber}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    surah.surahName,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Text(
                  _formatDuration(surah.duration),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play Button
// ─────────────────────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final bool isSelected;
  final bool isPlaying;

  const _PlayButton({required this.isSelected, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2DC4B2), Color(0xFF1FA99A)],
              )
            : null,
        color: isSelected ? null : AppColors.surfaceGrey,
        shape: BoxShape.circle,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: isSelected ? Colors.white : AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surahs Shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _SurahsShimmer extends StatefulWidget {
  const _SurahsShimmer();

  @override
  State<_SurahsShimmer> createState() => _SurahsShimmerState();
}

class _SurahsShimmerState extends State<_SurahsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E9F0),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      builder: (_, child) {
        return Opacity(opacity: 0.55 + 0.45 * _anim.value, child: child);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'لا توجد نتائج' : 'لا توجد تلاوات متاحة',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'جرب البحث بكلمة أخرى أو اختر قارئاً آخر'
                  : 'لا توجد تلاوات متاحة حالياً',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  context.read<AudioLibraryBloc>().add(
                    const SelectReciterEvent(null),
                  );
                  context.read<AudioLibraryBloc>().add(
                    const SearchAudioLibraryEvent(''),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DC4B2), Color(0xFF1FA99A)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'إلغاء الفلتر',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
