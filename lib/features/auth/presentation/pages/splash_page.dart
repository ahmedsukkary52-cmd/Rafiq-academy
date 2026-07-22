import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // الـ redirect بيتم تلقائياً من go_router لما الـ AuthBloc
      // يغيّر حالته — الـ Splash بس بتعرض شاشة الانتظار
      listener: (_, __) {},
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'رفيق',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'أكاديمية تحفيظ القرآن الكريم',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),

              const SizedBox(height: 64),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
