import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/presentation/pages/student_mushaf_page.dart';
import '../bloc/mushaf_audio_bloc.dart';
import '../bloc/mushaf_bloc.dart';
import '../bloc/mushaf_event.dart';

/// Student tab / route host — opens the reader directly with Blocs.
class MushafReaderHost extends StatefulWidget {
  /// Optional deep-link surah; when set with [forceSurahJump], jumps after load.
  final int? preferredSurah;
  final bool forceSurahJump;
  final MushafMode initialMode;

  const MushafReaderHost({
    super.key,
    this.preferredSurah,
    this.forceSurahJump = false,
    this.initialMode = MushafMode.reading,
  });

  @override
  State<MushafReaderHost> createState() => _MushafReaderHostState();
}

class _MushafReaderHostState extends State<MushafReaderHost> {
  @override
  void initState() {
    super.initState();
    // Warm Amiri (V1 Quran body font) without tying every style call to network.
    GoogleFonts.amiri();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<MushafBloc>().add(
      InitializeMushafEvent(
        studentId: auth.user.uid,
        preferredSurah: widget.preferredSurah,
        forceSurahJump: widget.forceSurahJump,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentMushafPage(
      initialMode: widget.initialMode,
      // Position is owned by MushafBloc (D23). Legacy surah/free flags unused.
    );
  }
}

/// Provides Mushaf + Audio blocs from DI for a subtree.
class MushafBlocScope extends StatelessWidget {
  final Widget child;

  const MushafBlocScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MushafBloc>.value(value: sl<MushafBloc>()),
        BlocProvider<MushafAudioBloc>.value(value: sl<MushafAudioBloc>()),
      ],
      child: child,
    );
  }
}
