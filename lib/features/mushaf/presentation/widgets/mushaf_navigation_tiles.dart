import 'package:flutter/material.dart';

import '../../domain/entities/mushaf_navigation_index.dart';
import '../../domain/mushaf_navigation_query.dart';
import '../../domain/mushaf_page_range.dart';
import 'mushaf_reader_tokens.dart';

String _digits(int n) => MushafReaderTokens.arabicDigits(n);

String mushafAyahCountLabel(int count) =>
    '${_digits(count)} ${count >= 3 && count <= 10 ? 'آيات' : 'آية'}';

/// "آخر موضع قراءة" — resume row at the top of the navigation sheet.
class MushafLastReadRow extends StatelessWidget {
  const MushafLastReadRow({
    super.key,
    required this.tokens,
    required this.title,
    required this.detail,
    required this.isCurrent,
    required this.onTap,
  });

  final MushafReaderTokens tokens;
  final String title;
  final String detail;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'آخر موضع قراءة: $title، $detail',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 20, color: tokens.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'آخر موضع قراءة',
                        style: tokens
                            .chromeLabelStyle(size: 11, weight: FontWeight.w500)
                            .copyWith(color: tokens.chromeMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.chromeLabelStyle(size: 14),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens
                            .chromeLabelStyle(size: 11, weight: FontWeight.w500)
                            .copyWith(color: tokens.chromeMuted),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Text(
                    'أنت هنا',
                    style: tokens
                        .chromeLabelStyle(size: 11, weight: FontWeight.w500)
                        .copyWith(color: tokens.accent),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: tokens.chromeMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  MushafReaderTokens tokens, {
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: tokens.canvas,
    hintText: hint,
    hintStyle: tokens
        .chromeLabelStyle(size: 13, weight: FontWeight.w400)
        .copyWith(color: tokens.chromeMuted),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border(tokens.divider),
    enabledBorder: border(tokens.divider),
    focusedBorder: border(tokens.accent),
  );
}

/// Compact "الانتقال إلى صفحة" field. Invalid input shows an inline message.
class MushafPageJumpField extends StatefulWidget {
  const MushafPageJumpField({
    super.key,
    required this.tokens,
    required this.onSubmit,
  });

  final MushafReaderTokens tokens;
  final ValueChanged<int> onSubmit;

  @override
  State<MushafPageJumpField> createState() => _MushafPageJumpFieldState();
}

class _MushafPageJumpFieldState extends State<MushafPageJumpField> {
  final _controller = TextEditingController();
  String? _error;

  static final _rangeMessage =
      'أدخل رقم صفحة من ${_digits(MushafPageRange.minPage)} '
      'إلى ${_digits(MushafPageRange.maxPage)}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final page = MushafPageInput.parse(_controller.text);
    if (page == null) {
      setState(() => _error = _rangeMessage);
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(page);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الانتقال إلى صفحة',
                style: tokens.chromeLabelStyle(size: 13),
              ),
            ),
            SizedBox(
              width: 104,
              child: TextField(
                key: const ValueKey('mushaf-page-jump-input'),
                controller: _controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: tokens.chromeLabelStyle(size: 14),
                cursorColor: tokens.accent,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  tokens,
                  hint: '${_digits(1)}–${_digits(604)}',
                ).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'انتقال إلى الصفحة',
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('mushaf-page-jump-go'),
                  onTap: _submit,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 48,
                    ),
                    child: Center(
                      child: Text(
                        'انتقال',
                        style: tokens
                            .chromeLabelStyle(size: 13)
                            .copyWith(color: tokens.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: tokens
                        .chromeLabelStyle(size: 11.5, weight: FontWeight.w500)
                        .copyWith(color: tokens.error),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Quiet two-label switch (السور / الأجزاء) with an accent underline.
class MushafNavTabs extends StatelessWidget {
  const MushafNavTabs({
    super.key,
    required this.tokens,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final MushafReaderTokens tokens;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          labels[i],
                          style: tokens
                              .chromeLabelStyle(
                                size: 14,
                                weight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              )
                              .copyWith(
                                color: i == selected
                                    ? tokens.chromeInk
                                    : tokens.chromeMuted,
                              ),
                        ),
                        PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 36),
                            color: i == selected
                                ? tokens.accent
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MushafSurahSearchField extends StatelessWidget {
  const MushafSurahSearchField({
    super.key,
    required this.tokens,
    required this.controller,
    required this.onChanged,
  });

  final MushafReaderTokens tokens;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('mushaf-surah-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: tokens.chromeLabelStyle(size: 14, weight: FontWeight.w500),
      cursorColor: tokens.accent,
      decoration: _fieldDecoration(
        tokens,
        hint: 'ابحث باسم السورة أو رقمها',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: tokens.chromeMuted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: tokens.chromeMuted,
                ),
              ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({
    required this.tokens,
    required this.number,
    required this.active,
  });

  final MushafReaderTokens tokens;
  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: active ? tokens.accent : tokens.divider),
      ),
      child: Text(
        _digits(number),
        style: tokens
            .chromeLabelStyle(size: 12)
            .copyWith(color: active ? tokens.accent : tokens.chromeMuted),
      ),
    );
  }
}

/// One list row for surah/juz lists. Fixed height so lists stay lazy.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.tokens,
    required this.number,
    required this.title,
    required this.titleStyle,
    required this.meta,
    required this.trailing,
    required this.active,
    required this.semanticsLabel,
    required this.onTap,
  });

  static const double height = 62;

  final MushafReaderTokens tokens;
  final int number;
  final String title;
  final TextStyle titleStyle;
  final String meta;
  final String trailing;
  final bool active;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: active ? tokens.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _NumberBadge(tokens: tokens, number: number, active: active),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens
                              .chromeLabelStyle(
                                size: 11,
                                weight: FontWeight.w500,
                              )
                              .copyWith(color: tokens.chromeMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trailing,
                    style: tokens
                        .chromeLabelStyle(size: 12, weight: FontWeight.w500)
                        .copyWith(color: tokens.chromeMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MushafSurahTile extends StatelessWidget {
  const MushafSurahTile({
    super.key,
    required this.tokens,
    required this.entry,
    required this.active,
    required this.onTap,
  });

  static const double height = _NavRow.height;

  final MushafReaderTokens tokens;
  final MushafSurahEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = entry.info;
    return _NavRow(
      tokens: tokens,
      number: info.number,
      title: info.name,
      titleStyle: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 18,
        height: 1.35,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: tokens.chromeInk,
      ),
      meta: '${info.revelationLabel} · ${mushafAyahCountLabel(info.ayahCount)}',
      trailing: 'ص ${_digits(entry.startPage)}',
      active: active,
      semanticsLabel:
          'سورة ${info.name}، ${info.revelationLabel}، '
          'صفحة ${_digits(entry.startPage)}',
      onTap: onTap,
    );
  }
}

class MushafJuzTile extends StatelessWidget {
  const MushafJuzTile({
    super.key,
    required this.tokens,
    required this.entry,
    required this.firstSurahName,
    required this.active,
    required this.onTap,
  });

  static const double height = _NavRow.height;

  final MushafReaderTokens tokens;
  final MushafJuzEntry entry;
  final String? firstSurahName;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final page = _digits(entry.startPage);
    return _NavRow(
      tokens: tokens,
      number: entry.number,
      title: entry.label,
      titleStyle: tokens.chromeLabelStyle(
        size: 14,
        weight: active ? FontWeight.w700 : FontWeight.w600,
      ),
      meta: firstSurahName == null
          ? 'يبدأ من صفحة $page'
          : 'يبدأ في سورة $firstSurahName',
      trailing: 'ص $page',
      active: active,
      semanticsLabel: '${entry.label}، صفحة $page',
      onTap: onTap,
    );
  }
}

/// Calm inline message for empty search results / missing data.
class MushafNavMessage extends StatelessWidget {
  const MushafNavMessage({
    super.key,
    required this.tokens,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final MushafReaderTokens tokens;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: tokens.chromeMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tokens.chromeLabelStyle(size: 14),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: tokens
                  .chromeLabelStyle(size: 12, weight: FontWeight.w500)
                  .copyWith(color: tokens.chromeMuted),
            ),
          ],
        ],
      ),
    );
  }
}
