import 'dart:async';

import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/providers/theme_mode_provider.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return GradientScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          SectionHeader(
            title: 'Settings',
            subtitle: 'Tune Agreeo to match your rhythm.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(state.session?.displayName ?? 'No session'),
              subtitle: Text(state.session?.email ?? 'Sign in to sync data'),
              trailing: state.session?.isGuest == true
                  ? const Chip(label: Text('Guest'))
                  : const Chip(label: Text('Signed in')),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: state.preferences.dailyRecommendationsEnabled,
            onChanged: (value) => ref
                .read(appControllerProvider.notifier)
                .setDailyRecommendationsEnabled(value),
            title: const Text('Daily recommendations'),
            subtitle: const Text(
              'Keep the movie of the day visible on the dashboard.',
            ),
          ),
          SwitchListTile.adaptive(
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              unawaited(
                ref
                    .read(appControllerProvider.notifier)
                    .setDarkModeEnabled(value),
              );
              unawaited(
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
              );
            },
            title: const Text('Dark mode'),
            subtitle: const Text('Use a darker palette for late-night swipes.'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: state.session == null
                ? null
                : () => ref
                      .read(appControllerProvider.notifier)
                      .regenerateDailyQueue(),
            child: const Text('Refresh daily queue'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: state.session == null
                ? null
                : () => ref.read(appControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
