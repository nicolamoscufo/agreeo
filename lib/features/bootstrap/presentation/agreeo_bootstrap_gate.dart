import 'package:agreeo/features/auth/presentation/auth_welcome_screen.dart';
import 'package:agreeo/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:agreeo/features/shell/presentation/agreeo_home_shell.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoBootstrapGate extends ConsumerWidget {
  const AgreeoBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agreeoAppControllerProvider);

    if (!state.hydrated) {
      return const _AgreeoLoadingScreen();
    }

    if (!state.isAuthenticated) {
      return const AgreeoAuthWelcomeScreen();
    }

    if (!state.onboardingComplete) {
      return const AgreeoOnboardingFlowScreen();
    }

    return const AgreeoHomeShell();
  }
}

class _AgreeoLoadingScreen extends StatelessWidget {
  const _AgreeoLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF020617),
              Color(0xFF0F172A),
              Color(0xFF111827),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Agreeo',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading tonight\'s prototype...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
