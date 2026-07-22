import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';

class ParentHomePage extends StatelessWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('نافذة ولي الأمر')),
      body: const Center(
        child: Text(
          'نافذة ولي الأمر — قريباً',
          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
      ),
    );
  }
}
