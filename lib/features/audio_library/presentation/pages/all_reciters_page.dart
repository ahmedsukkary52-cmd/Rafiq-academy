import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/audio_entities.dart';
import '../bloc/audio_bloc.dart';
import '../bloc/audio_event.dart';
import '../bloc/audio_state.dart';

class AllRecitersPage extends StatefulWidget {
  const AllRecitersPage({super.key});

  @override
  State<AllRecitersPage> createState() => _AllRecitersPageState();
}

class _AllRecitersPageState extends State<AllRecitersPage> {
  final _searchController = TextEditingController();
  final _query = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'كل القراء',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<String>(
                valueListenable: _query,
                builder: (context, query, _) {
                  return TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم القارئ',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _query.value = '';
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => _query.value = value.trim(),
                  );
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _query,
                builder: (context, rawQuery, _) {
                  return BlocBuilder<AudioLibraryBloc, AudioLibraryState>(
                    buildWhen: (previous, current) =>
                        previous.allReciters != current.allReciters ||
                        previous.favoriteReciters != current.favoriteReciters,
                    builder: (context, state) {
                      final query = _normalizeArabic(rawQuery);
                      final reciters = state.allReciters.where((reciter) {
                        if (query.isEmpty) return true;
                        return _normalizeArabic(reciter.name).contains(query);
                      }).toList();

                      if (reciters.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا يوجد قارئ بهذا الاسم',
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: reciters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reciter = reciters[index];
                          return _ReciterTile(
                            reciter: reciter,
                            isAdded: state.favoriteReciters.any(
                              (favorite) => favorite.id == reciter.id,
                            ),
                            onTap: () => _selectReciter(context, reciter),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectReciter(BuildContext context, ReciterEntity reciter) {
    final bloc = context.read<AudioLibraryBloc>();
    final alreadyAdded = bloc.state.favoriteReciters.any(
      (item) => item.id == reciter.id,
    );
    if (!alreadyAdded) {
      bloc.add(
        ToggleFollowReciterEvent(reciterId: reciter.id, isFollowing: true),
      );
    }
    bloc.add(SelectReciterEvent(reciter.id));
    Navigator.of(context).pop();
  }

  String _normalizeArabic(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .trim();
  }
}

class _ReciterTile extends StatelessWidget {
  final ReciterEntity reciter;
  final bool isAdded;
  final VoidCallback onTap;

  const _ReciterTile({
    required this.reciter,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            reciter.name.isEmpty ? '؟' : reciter.name.trim()[0],
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          reciter.name,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          reciter.recitationStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          isAdded ? Icons.check_circle_rounded : Icons.add_circle_outline,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
