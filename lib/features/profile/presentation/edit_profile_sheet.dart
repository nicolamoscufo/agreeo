import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/avatar_image_service.dart';
import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edit-profile sheet: profile photo (gallery picker → base64 data URI),
/// display name + bio → `updateProfile`, persisted via `PATCH /me/profile`.
/// Reference: `ag-states.jsx` EditProfileScreen.
Future<void> showEditProfileSheet(
  BuildContext context,
  AgreeoUserSession session,
) {
  return showAgSheet<void>(
    context: context,
    heightFactor: 0.78,
    child: _EditProfile(session: session),
  );
}

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile({required this.session});
  final AgreeoUserSession session;

  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late String _avatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.session.displayName);
    _bio = TextEditingController(text: widget.session.bio);
    _avatarUrl = widget.session.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dataUri = await AvatarImageService().pickAvatarDataUri();
      if (!mounted || dataUri == null) return;
      setState(() => _avatarUrl = dataUri);
    } on AvatarImageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not load that photo.')),
      );
    }
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(agreeoAppControllerProvider.notifier).updateProfile(
            displayName: _name.text,
            bio: _bio.text,
            avatarUrl:
                _avatarUrl == widget.session.avatarUrl ? null : _avatarUrl,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on BackendAuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the profile. Try again.')),
      );
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
          'Edit profile',
          style: AgText.h1.copyWith(letterSpacing: -0.5, color: t.text),
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _saving ? null : _pickAvatar,
                child: Stack(
                  children: [
                    AgAvatar(
                      name: widget.session.displayName,
                      color: t.red,
                      imageUrl: _avatarUrl.isEmpty ? null : _avatarUrl,
                      size: 84,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: t.grad,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.bg2, width: 2.5),
                        ),
                        child: const Icon(
                          AgIcons.camera,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_avatarUrl.isEmpty)
                Text(
                  'Tap to add a profile photo',
                  style: AgText.micro.copyWith(color: t.faint),
                )
              else
                GestureDetector(
                  onTap: _saving ? null : () => setState(() => _avatarUrl = ''),
                  child: Text(
                    'Remove photo',
                    style: AgText.label.copyWith(color: t.red),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Display name'),
        const SizedBox(height: 8),
        _Field(controller: _name, hint: 'Your name'),
        const SizedBox(height: 18),
        _FieldLabel('Bio / status'),
        const SizedBox(height: 8),
        _Field(
          controller: _bio,
          hint: 'Tell friends your taste…',
          maxLines: 4,
          focusBorder: true,
        ),
        const SizedBox(height: 22),
        AgButton(
          label: _saving ? 'Saving…' : 'Save profile',
          icon: AgIcons.check,
          onPressed: _saving ? null : _save,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(text, style: AgText.label.copyWith(color: t.text));
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.focusBorder = false,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool focusBorder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focusBorder ? t.red.withValues(alpha: 0.4) : t.line2,
          width: focusBorder ? 1.5 : 1,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: maxLines > 1 ? 12 : 0,
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: t.red,
        style: AgText.body.copyWith(fontWeight: FontWeight.w600, color: t.text),
        decoration: agBareInput(
          hint: hint,
          hintStyle: AgText.body.copyWith(color: t.faint),
          collapsed: maxLines == 1,
          contentPadding: maxLines == 1
              ? const EdgeInsets.symmetric(vertical: 15)
              : EdgeInsets.zero,
        ),
      ),
    );
  }
}
