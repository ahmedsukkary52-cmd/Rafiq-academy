import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/avatar_catalog.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_event.dart';
import '../bloc/student_state.dart';

enum _CatalogFilter { all, animals, premium }

class AvatarSelectionPage extends StatefulWidget {
  const AvatarSelectionPage({super.key});

  @override
  State<AvatarSelectionPage> createState() => _AvatarSelectionPageState();
}

class _AvatarSelectionPageState extends State<AvatarSelectionPage> {
  _CatalogFilter _filter = _CatalogFilter.all;
  String? _pendingSelection;

  List<AvatarDefinition> get _filtered {
    switch (_filter) {
      case _CatalogFilter.all:
        return AvatarCatalog.all;
      case _CatalogFilter.animals:
        return AvatarCatalog.all
            .where((a) => a.category == AvatarCategory.animals)
            .toList();
      case _CatalogFilter.premium:
        return AvatarCatalog.all
            .where((a) => a.category == AvatarCategory.premium)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StudentBloc, StudentState>(
      listenWhen: (p, c) => p.avatarUpdateStatus != c.avatarUpdateStatus,
      listener: (context, state) {
        if (state.avatarUpdateStatus == SectionStatus.loaded) {
          AppSnackBar.showSuccess(context, 'تم تحديث شخصيتك بنجاح');
        } else if (state.avatarUpdateStatus == SectionStatus.error) {
          AppSnackBar.showError(
            context,
            state.avatarUpdateError ?? 'حدث خطأ، حاول مرة أخرى',
          );
        }
      },
      builder: (context, state) {
        final profile = state.profile;
        final selectedId = _pendingSelection ?? profile?.avatarId ?? 'fox';
        final unlockedIds = profile?.unlockedAvatarIds ?? const ['fox'];
        final coins = profile?.coins ?? 0;
        final selected = AvatarCatalog.byId(selectedId);
        final isUpdating = state.avatarUpdateStatus == SectionStatus.loading;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.paddingL,
                  AppSizes.paddingXL,
                  AppSizes.paddingL,
                  AppSizes.paddingL,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'اختر شخصيتك 🎭',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'شخصيتك ستمثلك في رحلة الحفظ',
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            selected.emoji,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.paddingM),

              // ── فلاتر ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: _filter == _CatalogFilter.all,
                      onTap: () => setState(() => _filter = _CatalogFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'حيوانات',
                      selected: _filter == _CatalogFilter.animals,
                      onTap: () =>
                          setState(() => _filter = _CatalogFilter.animals),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'مميزة ✨',
                      selected: _filter == _CatalogFilter.premium,
                      onTap: () =>
                          setState(() => _filter = _CatalogFilter.premium),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.paddingM),

              // ── شبكة الشخصيات ─────────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingL,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final avatar = _filtered[i];
                    final isUnlocked = unlockedIds.contains(avatar.id);
                    final isSelected = avatar.id == selectedId;
                    final isEquipped = avatar.id == profile?.avatarId;

                    return _AvatarCard(
                      avatar: avatar,
                      isUnlocked: isUnlocked,
                      isSelected: isSelected,
                      isEquipped: isEquipped,
                      onTap: () {
                        if (!isUnlocked && coins < avatar.unlockCost) {
                          AppSnackBar.showInfo(
                            context,
                            'عملاتك مش كفاية لفتح ${avatar.name} (محتاج ${avatar.unlockCost} عملة)',
                          );
                          return;
                        }
                        setState(() => _pendingSelection = avatar.id);
                      },
                    );
                  },
                ),
              ),

              // ── رصيد العملات ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('🌙')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$coins نقطة متاحة',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const Text(
                                  'يمكنك فتح المزيد من الشخصيات',
                                  style: AppTextStyles.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'تأكيد الاختيار ${selected.emoji}',
                      isLoading: isUpdating,
                      onPressed: selectedId == profile?.avatarId
                          ? null
                          : () => _confirmSelection(
                              context,
                              profile,
                              selected,
                              unlockedIds,
                              coins,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmSelection(
    BuildContext context,
    StudentProfileEntity? profile,
    AvatarDefinition selected,
    List<String> unlockedIds,
    int coins,
  ) {
    if (profile == null) return;
    final alreadyUnlocked = unlockedIds.contains(selected.id);
    final newUnlocked = alreadyUnlocked
        ? unlockedIds
        : [...unlockedIds, selected.id];
    final newCoins = alreadyUnlocked ? coins : coins - selected.unlockCost;

    context.read<StudentBloc>().add(
      UpdateAvatarSelectionEvent(
        studentId: profile.uid,
        avatarId: selected.id,
        unlockedAvatarIds: newUnlocked,
        coins: newCoins,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final AvatarDefinition avatar;
  final bool isUnlocked;
  final bool isSelected;
  final bool isEquipped;
  final VoidCallback onTap;

  const _AvatarCard({
    required this.avatar,
    required this.isUnlocked,
    required this.isSelected,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isUnlocked ? 1 : 0.45,
                  child: Text(
                    avatar.emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  avatar.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUnlocked ? 'مجاني' : '${avatar.unlockCost} نقطة',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isUnlocked ? AppColors.success : AppColors.textHint,
                  ),
                ),
              ],
            ),
            if (isEquipped)
              const Positioned(
                top: 0,
                left: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            if (!isUnlocked)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
