import 'package:flutter/material.dart';

import 'mushaf_reader_tokens.dart';

/// Paper/Night page canvas with responsive margins and capped text measure.
class MushafPageSurface extends StatelessWidget {
  const MushafPageSurface({
    super.key,
    required this.tokens,
    required this.pageNumber,
    required this.child,
    this.bottomInset = 0,
  });

  final MushafReaderTokens tokens;
  final int pageNumber;
  final Widget child;

  /// Extra scroll room so the last lines can be lifted above bottom chrome.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hMargin = MushafReaderTokens.horizontalMargin(width);
    final vPad = MushafReaderTokens.verticalPadding(width);
    final maxW = MushafReaderTokens.maxTextWidth(width);

    return ColoredBox(
      color: tokens.canvas,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    hMargin,
                    vPad,
                    hMargin,
                    8 + bottomInset,
                  ),
                  child: child,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: vPad * 0.6),
                child: Text(
                  MushafReaderTokens.arabicDigits(pageNumber),
                  textAlign: TextAlign.center,
                  style: tokens.pageNumberStyle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm surah header — not a card.
class MushafSurahHeader extends StatelessWidget {
  const MushafSurahHeader({
    super.key,
    required this.tokens,
    required this.surahName,
    required this.surahNumber,
    required this.surahType,
  });

  final MushafReaderTokens tokens;
  final String surahName;
  final int surahNumber;
  final String surahType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(width: 48, height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          Text(
            'سورة $surahName',
            textAlign: TextAlign.center,
            style: tokens.surahTitleStyle(),
          ),
          const SizedBox(height: 4),
          Text(
            '${MushafReaderTokens.arabicDigits(surahNumber)} · $surahType',
            textAlign: TextAlign.center,
            style: tokens.surahMetaStyle(),
          ),
          const SizedBox(height: 12),
          Container(width: 48, height: 1, color: tokens.divider),
        ],
      ),
    );
  }
}
