import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings › Delete account. Asks for the password as an explicit
/// confirmation, then `DELETE /me` detaches the user node and everything it
/// is linked to in the graph. Pops back to the root so the auth welcome
/// screen takes over once the session is cleared.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showAgSheet<void>(context: context, child: const _DeleteAccount());
}

class _DeleteAccount extends ConsumerStatefulWidget {
  const _DeleteAccount();

  @override
  ConsumerState<_DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<_DeleteAccount> {
  late final TextEditingController _password;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(agreeoAppControllerProvider.notifier)
          .deleteAccount(password: _password.text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Pop the sheet and every pushed screen so the signed-out gate shows.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
    } on BackendAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete the account. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(AgIcons.trash, size: 24, color: t.red),
            const SizedBox(width: 10),
            Text(
              'Delete account',
              style: AgText.h1.copyWith(letterSpacing: -0.5, color: t.text),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'This permanently removes your profile, likes, watchlist, reviews, '
          'friendships and Movie Nights. There is no way back.',
          style: AgText.caption.copyWith(height: 1.5, color: t.sub),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.red.withValues(alpha: 0.4), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: t.red,
            style: AgText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
            decoration: agBareInput(
              hint: 'Password (required to confirm)',
              hintStyle: AgText.body.copyWith(color: t.faint),
              collapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AgText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: t.red,
            ),
          ),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _deleting ? null : _delete,
          child: Opacity(
            opacity: _deleting ? 0.6 : 1,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AgIcons.trash, size: 20, color: Colors.white),
                  const SizedBox(width: 9),
                  Text(
                    _deleting ? 'Deleting…' : 'Delete forever',
                    style: AgText.lead.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AgButton.secondary(
          label: 'Keep my account',
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
