import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart';
import '../domain/halaqa_meeting_link.dart';

/// What a screen knows about a halaqa's canonical meeting link.
sealed class MeetingLinkView {
  const MeetingLinkView();
}

final class MeetingLinkLoading extends MeetingLinkView {
  const MeetingLinkLoading();
}

/// The read succeeded; [link] is null when no link document exists.
final class MeetingLinkLoaded extends MeetingLinkView {
  final HalaqaMeetingLink? link;
  const MeetingLinkLoaded(this.link);

  MeetingLinkAvailability get availability => meetingLinkAvailability(link);

  /// The link only when it may be opened or displayed.
  String? get joinableLink => availability == MeetingLinkAvailability.joinable
      ? link!.meetingLink
      : null;
}

final class MeetingLinkDenied extends MeetingLinkView {
  const MeetingLinkDenied();
}

final class MeetingLinkFailed extends MeetingLinkView {
  final String message;
  const MeetingLinkFailed(this.message);
}

typedef MeetingLinkViewBuilder =
    Widget Function(
      BuildContext context,
      MeetingLinkView view,
      VoidCallback reload,
    );

/// Loads `halaqaMeetingLinks/{halaqaId}` through [GetHalaqaMeetingLinkUseCase]
/// and reloads when [halaqaId] or [reloadToken] (compared by identity)
/// changes.
class HalaqaMeetingLinkBuilder extends StatefulWidget {
  final String halaqaId;
  final Object? reloadToken;
  final MeetingLinkViewBuilder builder;

  const HalaqaMeetingLinkBuilder({
    super.key,
    required this.halaqaId,
    required this.builder,
    this.reloadToken,
  });

  @override
  State<HalaqaMeetingLinkBuilder> createState() =>
      _HalaqaMeetingLinkBuilderState();
}

class _HalaqaMeetingLinkBuilderState extends State<HalaqaMeetingLinkBuilder> {
  MeetingLinkView _view = const MeetingLinkLoading();
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant HalaqaMeetingLinkBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.halaqaId != widget.halaqaId ||
        !identical(oldWidget.reloadToken, widget.reloadToken)) {
      _view = const MeetingLinkLoading();
      _fetch();
    }
  }

  void _reload() {
    setState(() => _view = const MeetingLinkLoading());
    _fetch();
  }

  Future<void> _fetch() async {
    final request = ++_request;
    final result = await sl<GetHalaqaMeetingLinkUseCase>()(widget.halaqaId);
    if (!mounted || request != _request) return;
    setState(() {
      _view = result.fold(
        (f) => f is MeetingLinkAccessDeniedFailure
            ? const MeetingLinkDenied()
            : MeetingLinkFailed(f.message),
        MeetingLinkLoaded.new,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _view, _reload);
}
