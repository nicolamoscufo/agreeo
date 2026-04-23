import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/screens/auth/auth_welcome_screen.dart';
import 'package:agreeo/screens/home/home_shell.dart';
import 'package:agreeo/screens/onboarding/onboarding_screen.dart';
import 'package:agreeo/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBootstrapGate extends ConsumerWidget {
  const AppBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);

    if (!state.hydrated) {
      return const SplashScreen();
    }

    if (state.session == null) {
      return const AuthWelcomeScreen();
    }

    if (!state.onboardingComplete) {
      return const OnboardingScreen();
    }

    return const HomeShell();
  }
}
