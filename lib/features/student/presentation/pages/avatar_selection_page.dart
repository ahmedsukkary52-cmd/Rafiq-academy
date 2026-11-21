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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<StudentBloc, StudentState>(
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'اختر شخصيتك',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'شخصيتك ستمثلك في رحلة الحفظ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.95),
                                Colors.white.withValues(alpha: 0.75),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              selected.emoji,
                              style: const TextStyle(fontSize: 52),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          selected.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'الكل',
                        selected: _filter == _CatalogFilter.all,
                        onTap: () =>
                            setState(() => _filter = _CatalogFilter.all),
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
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final avatar = _filtered[i];
                      final isUnlocked = unlockedIds.contains(avatar.id);
                      final isSelected = avatar.id == selectedId;
                      final isEquipped = avatar.id == profile?.avatarId;

                      return _AvatarBubble(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
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
                                    '$coins عملة متاحة',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'افتح المزيد من الشخصيات الجميلة',
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
      ),
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final AvatarDefinition avatar;
  final bool isUnlocked;
  final bool isSelected;
  final bool isEquipped;
  final VoidCallback onTap;

  const _AvatarBubble({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight,
                          AppColors.primary.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                    child: Opacity(
                      opacity: isUnlocked ? 1 : 0.4,
                      child: Text(
                        avatar.emoji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 34, height: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    avatar.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked ? 'مجاني' : '${avatar.unlockCost} عملة',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isUnlocked
                          ? AppColors.primaryDark
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (isEquipped)
              const Positioned(
                top: 0,
                left: 0,
                child: CircleAvatar(
                  radius: 11,
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
