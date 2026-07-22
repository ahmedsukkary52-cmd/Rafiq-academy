import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('نافذة المدير')),
      body: const Center(
        child: Text(
          'نافذة المدير — قريباً',
          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
      ),
    );
  }
}
