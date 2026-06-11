import 'dart:ui';

import 'package:agreeo/shared/state/nav_index_provider.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_effects.dart';
import 'package:agreeo/shared/ui/ag_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical Daylight tab indices for [navIndexProvider]. Profile is NOT a tab —
/// it opens from the header avatar (per the resolved nav decision). The center
/// FAB triggers movie-night create via [onCenterTap].
class AgNavTab {
  static const int home = 0;
  static const int swipe = 1;
  static const int library = 2;
  static const int friends = 3;
}

/// Floating glass bottom navigation: blur 18 + glass fill + line2 border
/// (radius 24), with a raised gradient Movie-Night FAB in the center.
/// Reference: `ag-shared.jsx` `BottomNav`.
class AgGlassBottomNav extends ConsumerWidget {
  const AgGlassBottomNav({super.key, required this.onCenterTap});

  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final active = ref.watch(navIndexProvider);

    void select(int index) {
      HapticFeedback.selectionClick();
      ref.read(navIndexProvider.notifier).state = index;
    }

    final bar = Container(
      height: 62,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: kEnableBlur
              ? ImageFilter.blur(sigmaX: 18, sigmaY: 18)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            decoration: BoxDecoration(
              color: kEnableBlur ? t.glass : t.surface2,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.line2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: AgIcons.home,
                  label: 'Home',
                  active: active == AgNavTab.home,
                  onTap: () => select(AgNavTab.home),
                ),
                _NavItem(
                  icon: AgIcons.cards,
                  label: 'Swipe',
                  active: active == AgNavTab.swipe,
                  onTap: () => select(AgNavTab.swipe),
                ),
                const SizedBox(width: 50), // space for the center FAB
                _NavItem(
                  icon: AgIcons.library,
                  label: 'Library',
                  active: active == AgNavTab.library,
                  onTap: () => select(AgNavTab.library),
                ),
                _NavItem(
                  icon: AgIcons.users,
                  label: 'Friends',
                  active: active == AgNavTab.friends,
                  onTap: () => select(AgNavTab.friends),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final fab = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onCenterTap();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: t.grad,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: t.bg, width: 3),
          boxShadow: [
            BoxShadow(
              color: t.purple.withValues(alpha: 0.7),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Icon(AgIcons.film, size: 24, color: Colors.white),
      ),
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [t.bg, t.bg.withValues(alpha: 0)],
          stops: const [0.55, 1],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          bar,
          Positioned(top: -16, child: fab),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.red : t.faint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 10,
                color: active ? t.text : t.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
