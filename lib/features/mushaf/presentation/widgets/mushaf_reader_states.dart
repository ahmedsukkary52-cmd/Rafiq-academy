import 'package:flutter/material.dart';

import 'mushaf_reader_tokens.dart';

/// Soft paper-like loading surface for the reader.
class MushafReaderLoading extends StatelessWidget {
  const MushafReaderLoading({super.key, required this.tokens});

  final MushafReaderTokens tokens;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hMargin = MushafReaderTokens.horizontalMargin(width);

    return ColoredBox(
      color: tokens.canvas,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: minLineWidth(width),
                child: Column(
                  children: [
                    _line(tokens, 0.92),
                    const SizedBox(height: 14),
                    _line(tokens, 0.78),
                    const SizedBox(height: 14),
                    _line(tokens, 0.86),
                    const SizedBox(height: 14),
                    _line(tokens, 0.64),
                    const SizedBox(height: 14),
                    _line(tokens, 0.8),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'جاري تحميل المصحف…',
                style: tokens
                    .chromeLabelStyle(size: 14, weight: FontWeight.w500)
                    .copyWith(color: tokens.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double minLineWidth(double width) =>
      (width * 0.72).clamp(180.0, 420.0);

  static Widget _line(MushafReaderTokens tokens, double fraction) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: tokens.ink.withValues(alpha: tokens.isNight ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Arabic reader error with retry — visually part of the mushaf surface.
class MushafReaderError extends StatelessWidget {
  const MushafReaderError({
    super.key,
    required this.tokens,
    required this.message,
    required this.onRetry,
  });

  final MushafReaderTokens tokens;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 40, color: tokens.inkMuted),
              const SizedBox(height: 16),
              Text(
                'تعذر تحميل نص المصحف',
                textAlign: TextAlign.center,
                style: tokens.chromeLabelStyle(size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                message.isEmpty ? 'تحقق من الاتصال ثم أعد المحاولة.' : message,
                textAlign: TextAlign.center,
                style: tokens
                    .chromeLabelStyle(size: 13, weight: FontWeight.w500)
                    .copyWith(color: tokens.inkMuted),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: tokens.accent,
                  minimumSize: const Size(48, 44),
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: tokens
                      .chromeLabelStyle(size: 15)
                      .copyWith(color: tokens.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
