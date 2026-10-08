import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../pages/teacher_excuses_page.dart';

/// Isolated host for Teacher استئذان review (production page).
class TeacherExcusesPreviewApp extends StatelessWidget {
  const TeacherExcusesPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const TeacherExcusesPage(),
    );
  }
}
