import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings › Change password. Mirrors the backend policy (min 8 chars with
/// at least one letter and one digit) client-side, then `POST /me/password`.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showAgSheet<void>(context: context, child: const _ChangePassword());
}

class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();

  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  late final TextEditingController _current;
  late final TextEditingController _next;
  late final TextEditingController _confirm;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current = TextEditingController();
    _next = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_current.text.isEmpty) return 'Enter your current password.';
    final next = _next.text;
    if (next.length < 8 ||
        !next.contains(RegExp('[a-zA-Z]')) ||
        !next.contains(RegExp('[0-9]'))) {
      return 'New password needs at least 8 characters, with a letter and a digit.';
    }
    if (next != _confirm.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(agreeoAppControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
    } on BackendAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not change the password. Try again.';
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
        Text(
          'Change password',
          style: AgText.h1.copyWith(letterSpacing: -0.5, color: t.text),
        ),
        const SizedBox(height: 6),
        Text(
          'At least 8 characters, with one letter and one digit.',
          style: AgText.caption.copyWith(color: t.sub),
        ),
        const SizedBox(height: 20),
        _PasswordField(controller: _current, hint: 'Current password'),
        const SizedBox(height: 12),
        _PasswordField(controller: _next, hint: 'New password'),
        const SizedBox(height: 12),
        _PasswordField(controller: _confirm, hint: 'Repeat new password'),
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
        AgButton(
          label: _saving ? 'Updating…' : 'Update password',
          icon: AgIcons.lock,
          onPressed: _saving ? null : _save,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: t.red,
        style: AgText.body.copyWith(fontWeight: FontWeight.w600, color: t.text),
        decoration: agBareInput(
          hint: hint,
          hintStyle: AgText.body.copyWith(color: t.faint),
          collapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
