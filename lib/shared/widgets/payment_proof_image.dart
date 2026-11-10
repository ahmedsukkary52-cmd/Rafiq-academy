import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' show Either;

import '../../core/error/failure.dart';
import '../domain/payment_proof_reader.dart';
import '../theme/app_theme.dart';

typedef PaymentProofBytesLoader =
    Future<Either<Failure, Uint8List>> Function(
      DownloadPaymentProofParams params,
    );

/// Shown instead of review decisions while the proof image is unavailable.
const String kPaymentProofNotLoadedMessage =
    'لا يمكن اتخاذ قرار قبل تحميل صورة الإيصال';

/// Payment-proof image for Admin / Supervisor review. Loads
/// `proofStoragePath` through Storage Rules; never a persisted URL.
class PaymentProofImage extends StatefulWidget {
  final String parentId;
  final String paymentId;
  final String? storagePath;
  final double height;

  /// Production callers pass [DownloadPaymentProofUseCase.call], which fails
  /// closed on an untrusted `proofStoragePath`.
  final PaymentProofBytesLoader loader;

  /// `true` once the image is decoded and painted; `false` while it is
  /// (re)loading or after a download / decode failure. Reported after the
  /// frame, latest state last.
  final ValueChanged<bool>? onLoadedChanged;

  const PaymentProofImage({
    super.key,
    required this.parentId,
    required this.paymentId,
    required this.storagePath,
    required this.loader,
    this.height = 180,
    this.onLoadedChanged,
  });

  @override
  State<PaymentProofImage> createState() => _PaymentProofImageState();
}

class _PaymentProofImageState extends State<PaymentProofImage> {
  late Future<Either<Failure, Uint8List>> _future;
  bool _loaded = false;

  void _setLoaded(bool loaded) {
    if (_loaded == loaded) return;
    _loaded = loaded;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loaded == loaded) widget.onLoadedChanged?.call(loaded);
    });
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PaymentProofImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.paymentId != widget.paymentId ||
        oldWidget.parentId != widget.parentId) {
      _future = _load();
    }
  }

  Future<Either<Failure, Uint8List>> _load() {
    _setLoaded(false);
    return widget.loader(
      DownloadPaymentProofParams(
        parentId: widget.parentId,
        paymentId: widget.paymentId,
        storagePath: widget.storagePath ?? '',
      ),
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  Widget _message(String text, {bool retry = false}) {
    return Container(
      height: widget.height / 2,
      color: AppColors.surfaceGrey,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
          ),
          if (retry)
            TextButton(onPressed: _retry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, Uint8List>>(
      future: _future,
      builder: (context, snapshot) {
        // FutureBuilder keeps the previous proof's data while a new load is
        // pending; showing it would pass off a stale image as the current one.
        final result = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        if (result == null) {
          if (snapshot.hasError) {
            _setLoaded(false);
            return _message('تعذر تحميل صورة الإيصال', retry: true);
          }
          return SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return result.fold(
          (failure) {
            _setLoaded(false);
            return _message(
              failure.message,
              retry: failure is! ValidationFailure,
            );
          },
          (bytes) {
            Widget image(BoxFit fit, {double? height, bool report = false}) =>
                Image.memory(
                  bytes,
                  height: height,
                  fit: fit,
                  frameBuilder: (_, child, frame, __) {
                    if (report && frame != null) _setLoaded(true);
                    return child;
                  },
                  errorBuilder: (_, __, ___) {
                    if (report) _setLoaded(false);
                    return _message('تعذر عرض صورة الإيصال');
                  },
                );
            return InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(child: image(BoxFit.contain)),
                ),
              ),
              child: image(BoxFit.cover, height: widget.height, report: true),
            );
          },
        );
      },
    );
  }
}
