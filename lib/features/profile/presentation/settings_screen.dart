import 'package:agreeo/config/app_links.dart';
import 'package:agreeo/features/debug/presentation/neo4j_console_screen.dart';
import 'package:agreeo/features/profile/presentation/blocked_users_screen.dart';
import 'package:agreeo/features/profile/presentation/change_password_sheet.dart';
import 'package:agreeo/features/profile/presentation/delete_account_sheet.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/theme_mode_provider.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cached once so the version row doesn't re-query the platform on rebuild.
final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open the link.")),
    );
  }
}

Future<void> _openSupportEmail(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: AppLinks.supportEmail,
    queryParameters: const {'subject': 'Agreeo support'},
  );
  if (!await launchUrl(uri)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No mail app found. Email ${AppLinks.supportEmail}'),
      ),
    );
  }
}

/// Profile › Settings. Appearance (theme mode), Privacy, Notifications, Account,
/// Log out. Reference: `ag-states.jsx` SettingsScreen.
class AgreeoSettingsScreen extends ConsumerWidget {
  const AgreeoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final prefs = state.profilePreferences;
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  _BackButton(),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: AgText.h2.copyWith(
                      letterSpacing: -0.5,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                children: [
                  _SectionTitle(icon: AgIcons.moon, title: 'Appearance'),
                  const SizedBox(height: 9),
                  _ThemeSelector(
                    mode: themeMode,
                    onChanged: (m) =>
                        ref.read(themeModeProvider.notifier).setMode(m),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: AgIcons.shield, title: 'Privacy'),
                  const SizedBox(height: 9),
                  _Card(
                    rows: [
                      _ToggleRow(
                        icon: AgIcons.eye,
                        title: 'Show watched to friends',
                        value: prefs.showWatchedToFriends,
                        onChanged: (v) => controller.setPrivacyPreference(
                          showWatchedToFriends: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.heart,
                        title: 'Show liked to friends',
                        value: prefs.showLikedToFriends,
                        onChanged: (v) => controller.setPrivacyPreference(
                          showLikedToFriends: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.bookmark,
                        title: 'Show watchlist to friends',
                        value: prefs.showWatchlistToFriends,
                        onChanged: (v) => controller.setPrivacyPreference(
                          showWatchlistToFriends: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.edit,
                        title: 'Show reviews to friends',
                        value: prefs.showReviewsToFriends,
                        onChanged: (v) => controller.setPrivacyPreference(
                          showReviewsToFriends: v,
                        ),
                      ),
                      _NavRow(
                        icon: AgIcons.shield,
                        title: 'Blocked users',
                        subtitle: 'See and unblock people you blocked',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BlockedUsersScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: AgIcons.bell, title: 'Notifications'),
                  const SizedBox(height: 9),
                  _Card(
                    rows: [
                      _ToggleRow(
                        icon: AgIcons.bulb,
                        title: 'Daily suggestion reminder',
                        value: prefs.dailySuggestionReminder,
                        onChanged: (v) => controller.setNotificationPreference(
                          dailySuggestionReminder: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.film,
                        title: 'Movie Night invites',
                        value: prefs.movieNightInvites,
                        onChanged: (v) => controller.setNotificationPreference(
                          movieNightInvites: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.vote,
                        title: 'Voting started',
                        value: prefs.votingStarted,
                        onChanged: (v) => controller.setNotificationPreference(
                          votingStarted: v,
                        ),
                      ),
                      _ToggleRow(
                        icon: AgIcons.trophy,
                        title: 'Final decision reached',
                        value: prefs.finalDecisionReached,
                        onChanged: (v) => controller.setNotificationPreference(
                          finalDecisionReached: v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: AgIcons.settings, title: 'Account'),
                  const SizedBox(height: 9),
                  _Card(
                    rows: [
                      _InfoRow(
                        icon: AgIcons.mail,
                        title: state.session?.email ?? 'you@agreeo.app',
                        subtitle: 'Signed in',
                      ),
                      _NavRow(
                        icon: AgIcons.lock,
                        title: 'Change password',
                        subtitle: 'Update your sign-in password',
                        onTap: () => showChangePasswordSheet(context),
                      ),
                      _NavRow(
                        icon: AgIcons.trash,
                        title: 'Delete account',
                        subtitle: 'Permanently erase your data',
                        danger: true,
                        onTap: () => showDeleteAccountSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.info_outline_rounded,
                    title: 'About & Support',
                  ),
                  const SizedBox(height: 9),
                  _Card(
                    rows: [
                      _NavRow(
                        icon: AgIcons.shield,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () =>
                            _openExternalUrl(context, AppLinks.privacyPolicy),
                      ),
                      _NavRow(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'The rules for using Agreeo',
                        onTap: () =>
                            _openExternalUrl(context, AppLinks.termsOfService),
                      ),
                      _NavRow(
                        icon: AgIcons.mail,
                        title: 'Contact support',
                        subtitle: 'Questions, bugs or feedback',
                        onTap: () => _openSupportEmail(context),
                      ),
                      _NavRow(
                        icon: AgIcons.star,
                        title: 'Rate Agreeo',
                        subtitle: 'Leave a review on the store',
                        onTap: () =>
                            _openExternalUrl(context, AppLinks.storeListing),
                      ),
                      const _VersionRow(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: AgIcons.sliders, title: 'Developer'),
                  const SizedBox(height: 9),
                  _Card(
                    rows: [
                      _NavRow(
                        icon: AgIcons.sparkle,
                        title: 'Recommendation Lab',
                        subtitle: 'Engine, scoring and live Cypher queries',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const Neo4jConsoleScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _LogoutButton(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final navigator = Navigator.of(context);
                      await controller.logOut();
                      // Pop Settings/Profile so the signed-out gate is visible.
                      navigator.popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Back',
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: Icon(AgIcons.chevronLeft, size: 20, color: t.text),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: t.gold),
        const SizedBox(width: 9),
        Text(
          title,
          style: AgText.h4.copyWith(
            fontSize: 14.5,
            letterSpacing: -0.3,
            color: t.text,
          ),
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.mode, required this.onChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const items = [
      (ThemeMode.light, 'Light', AgIcons.bulb),
      (ThemeMode.dark, 'Dark', AgIcons.moon),
      (ThemeMode.system, 'System', AgIcons.settings),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: items
            .map((item) {
              final on = mode == item.$1;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: on,
                  label: '${item.$2} theme',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onChanged(item.$1),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: on ? t.grad : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.$3,
                            size: 18,
                            color: on ? Colors.white : t.sub,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.$2,
                            style: AgText.label.copyWith(
                              fontSize: 14,
                              color: on ? Colors.white : t.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Merge the label + switch into a single accessibility node so screen
    // readers announce e.g. "Show watched films to friends, switch, on".
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 20, color: t.sub),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: AgText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
            ),
            _GradientSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _GradientSwitch extends StatelessWidget {
  const _GradientSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 29,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            gradient: value ? t.grad : null,
            color: value ? null : t.surface2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: value ? Colors.transparent : t.line2),
          ),
          child: Container(
            width: 23,
            height: 23,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.sub),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AgText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: AgText.micro.copyWith(color: t.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only row in About & Support showing the installed app version/build.
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? '—'
            : '${info.version} (${info.buildNumber})';
        return _InfoRow(
          icon: Icons.info_outline_rounded,
          title: 'Version',
          subtitle: version,
        );
      },
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Tints icon and title red for destructive entries (e.g. Delete account).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? t.red : t.sub),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AgText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? t.red : t.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AgText.micro.copyWith(color: t.faint),
                    ),
                ],
              ),
            ),
            Icon(AgIcons.chevron, size: 20, color: t.faint),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AgIcons.logout, size: 20, color: t.red),
            const SizedBox(width: 9),
            Text(
              'Log out',
              style: AgText.label.copyWith(fontSize: 15, color: t.red),
            ),
          ],
        ),
      ),
    );
  }
}
