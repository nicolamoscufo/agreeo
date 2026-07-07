import 'package:agreeo/features/auth/presentation/auth_welcome_screen.dart';
import 'package:agreeo/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:agreeo/features/shell/presentation/agreeo_home_shell.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // Cinematic vertical wash + accent bloom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg, t.bg2, t.surface],
                  stops: const [0, 0.55, 1.2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [
                    t.purple.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: t.grad,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: t.purple.withValues(alpha: 0.55),
                        blurRadius: 44,
                        offset: const Offset(0, 18),
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    AgIcons.play,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Agreeo',
                  style: AgText.display.copyWith(
                    fontSize: 42,
                    height: 1,
                    letterSpacing: -1.5,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Agree on what to watch, faster.',
                  style: AgText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: t.sub,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 78,
            child: Column(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: t.red,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Curating tonight's lineup…",
                  style: AgText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: t.faint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
