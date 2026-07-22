import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';

class SupervisorHomePage extends StatelessWidget {
  const SupervisorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('نافذة المشرف')),
      body: const Center(
        child: Text(
          'نافذة المشرف — قريباً',
          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
      ),
    );
  }
}
