import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/academy_branding.dart';
import '../../../../shared/theme/app_theme.dart';
import '../bloc/client_version_gate_bloc.dart';

typedef UpdateUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// B10 blocking screen for a build below `minimumBuildNumber`. The router
/// keeps every other route unreachable; back navigation is disabled here.
class UpdateRequiredPage extends StatelessWidget {
  final UpdateUrlOpener openUrl;

  const UpdateRequiredPage({super.key, this.openUrl = _openExternally});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: BlocBuilder<ClientVersionGateBloc, ClientVersionGateState>(
                builder: (context, state) => _UpdateRequiredBody(
                  updateUrl: state.config?.updateUrlFor(defaultTargetPlatform),
                  isRechecking: state.isRechecking,
                  openUrl: openUrl,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateRequiredBody extends StatelessWidget {
  final Uri? updateUrl;
  final bool isRechecking;
  final UpdateUrlOpener openUrl;

  const _UpdateRequiredBody({
    required this.updateUrl,
    required this.isRechecking,
    required this.openUrl,
  });

  static const _textStyle = TextStyle(
    fontFamily: 'NotoNaskhArabic',
    fontSize: 15,
    color: Colors.white,
    height: 1.6,
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openUrl(uri);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر فتح رابط التحديث')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = updateUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.system_update_rounded, color: Colors.white, size: 64),
        const SizedBox(height: 20),
        const Text(
          'يلزم تحديث التطبيق',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'هذا الإصدار من تطبيق ${AcademyBranding.shortName} لم يعد مدعومًا. '
          'حدّث التطبيق إلى أحدث إصدار للمتابعة.',
          textAlign: TextAlign.center,
          style: _textStyle,
        ),
        if (url == null) ...[
          const SizedBox(height: 8),
          const Text(
            'تواصل مع إدارة الأكاديمية للحصول على أحدث إصدار.',
            textAlign: TextAlign.center,
            style: _textStyle,
          ),
        ],
        const SizedBox(height: 28),
        if (url != null) ...[
          FilledButton.icon(
            key: const Key('updateRequiredOpenStore'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => _open(context, url),
            icon: const Icon(Icons.download_rounded),
            label: const Text('تحديث التطبيق'),
          ),
          const SizedBox(height: 8),
        ],
        TextButton.icon(
          key: const Key('updateRequiredRetry'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: isRechecking
              ? null
              : () => context.read<ClientVersionGateBloc>().add(
                  const ClientVersionCheckRequested(),
                ),
          icon: isRechecking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('إعادة التحقق'),
        ),
      ],
    );
  }
}
