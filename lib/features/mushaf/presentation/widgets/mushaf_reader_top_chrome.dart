import 'package:flutter/material.dart';

import 'mushaf_reader_tokens.dart';

/// Thin top chrome — subordinate to Quran text.
class MushafReaderTopChrome extends StatelessWidget {
  const MushafReaderTopChrome({
    super.key,
    required this.tokens,
    required this.surahName,
    required this.pageNumber,
    required this.visible,
    required this.onToggleNight,
    required this.onOpenNavigation,
    required this.onOpenSettings,
    this.onBack,
    this.onOpenRecitation,
  });

  final MushafReaderTokens tokens;
  final String surahName;
  final int pageNumber;
  final bool visible;
  final VoidCallback onToggleNight;

  /// Opens the surah / juz / page navigation sheet.
  final VoidCallback onOpenNavigation;
  final VoidCallback onOpenSettings;
  final VoidCallback? onBack;
  final VoidCallback? onOpenRecitation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -1.05),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: ColoredBox(
            color: tokens.chrome.withValues(alpha: 0.96),
            child: Material(
              color: tokens.chrome.withValues(alpha: 0.96),
              elevation: 0,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                  child: Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          tooltip: 'رجوع',
                          onPressed: onBack,
                          icon: Icon(
                            // Auto-mirrors: points right (→) in RTL.
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: tokens.chromeInk,
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              'سورة $surahName، صفحة ${MushafReaderTokens.arabicDigits(pageNumber)}. فتح التنقّل',
                          excludeSemantics: true,
                          child: InkWell(
                            key: const ValueKey('mushaf-chrome-title'),
                            onTap: onOpenNavigation,
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surahName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.chromeLabelStyle(size: 15),
                                ),
                                Text(
                                  'صفحة ${MushafReaderTokens.arabicDigits(pageNumber)}',
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
                        ),
                      ),
                      IconButton(
                        tooltip: tokens.isNight ? 'وضع الورق' : 'الوضع الليلي',
                        onPressed: onToggleNight,
                        icon: Icon(
                          tokens.isNight
                              ? Icons.wb_sunny_outlined
                              : Icons.dark_mode_outlined,
                          size: 20,
                          color: tokens.chromeInk,
                        ),
                      ),
                      IconButton(
                        tooltip: 'التنقّل',
                        onPressed: onOpenNavigation,
                        icon: Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 20,
                          color: tokens.chromeInk,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'المزيد',
                        color: tokens.chrome,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: tokens.chromeInk,
                        ),
                        onSelected: (value) {
                          if (value == 'settings') {
                            onOpenSettings();
                          } else if (value == 'recitation' &&
                              onOpenRecitation != null) {
                            onOpenRecitation!();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'settings',
                            child: Text(
                              'إعدادات القراءة',
                              style: tokens.chromeLabelStyle(size: 14),
                            ),
                          ),
                          if (onOpenRecitation != null)
                            PopupMenuItem(
                              value: 'recitation',
                              child: Text(
                                'التسميع',
                                style: tokens.chromeLabelStyle(size: 14),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
