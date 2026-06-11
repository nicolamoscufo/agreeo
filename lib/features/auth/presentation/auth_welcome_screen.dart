import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _AuthMode { signUp, logIn }

class AgreeoAuthWelcomeScreen extends ConsumerStatefulWidget {
  const AgreeoAuthWelcomeScreen({super.key});

  @override
  ConsumerState<AgreeoAuthWelcomeScreen> createState() => _AgreeoAuthWelcomeScreenState();
}

class _AgreeoAuthWelcomeScreenState extends ConsumerState<AgreeoAuthWelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  _AuthMode _mode = _AuthMode.logIn;

  bool get _isSignUp => _mode == _AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() {
        _mode = _isSignUp ? _AuthMode.logIn : _AuthMode.signUp;
        _formKey.currentState?.reset();
      });

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (!_isSignUp) return null;
    // Mirrors the backend policy for new accounts; logins stay lenient so
    // users with older passwords can still sign in.
    if (value.length < 8 ||
        !value.contains(RegExp(r'[a-zA-Z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return 'Use at least 8 characters with a letter and a number';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final controller = ref.read(agreeoAppControllerProvider.notifier);
      if (_isSignUp) {
        await controller.signUp(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await controller.logIn(email: _emailController.text, password: _passwordController.text);
      }
    } on BackendAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          const _PosterFan(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 80),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 220),
                      const _Wordmark(size: 34),
                      const SizedBox(height: 20),
                      _Headline(isSignUp: _isSignUp),
                      const SizedBox(height: 22),
                      if (_isSignUp) ...[
                        _Field(
                          label: 'Display name',
                          controller: _nameController,
                          hint: 'Your name',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _Field(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'you@email.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'Password',
                        controller: _passwordController,
                        hint: _isSignUp ? 'At least 8 characters' : 'Password',
                        obscure: _obscure,
                        onToggleObscure: () => setState(() => _obscure = !_obscure),
                        validator: _validatePassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      AgButton(
                        label: _submitting ? 'Please wait…' : (_isSignUp ? 'Create account' : 'Log in'),
                        icon: AgIcons.arrow,
                        onPressed: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _toggleMode,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.faint),
                              text: _isSignUp ? 'Already have an account? ' : 'New here? ',
                              children: [
                                TextSpan(
                                  text: _isSignUp ? 'Log in' : 'Create an account',
                                  style: TextStyle(color: t.red, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.isSignUp});
  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (isSignUp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create your account', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 29, height: 1.05, letterSpacing: -0.7, color: t.text)),
          const SizedBox(height: 8),
          Text("It takes about a minute. We'll tune your taste next.", style: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.45, color: t.sub)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 30, height: 1.05, letterSpacing: -0.8, color: t.text),
            children: [
              const TextSpan(text: 'Movie night,\nfinally '),
              WidgetSpan(
                child: ShaderMask(
                  shaderCallback: (rect) => t.grad.createShader(rect),
                  child: const Text('agreed.', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 30, letterSpacing: -0.8, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('Discover films, build your taste, and decide together — no more endless scrolling.', style: TextStyle(fontFamily: 'Manrope', fontSize: 14.5, height: 1.45, color: t.sub)),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.12,
          height: size * 1.12,
          decoration: BoxDecoration(
            gradient: t.grad,
            borderRadius: BorderRadius.circular(size * 0.34),
            boxShadow: [BoxShadow(color: t.purple.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4)],
          ),
          child: Icon(AgIcons.play, size: size * 0.6, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Text('Agreeo', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: size, letterSpacing: -0.8, color: t.text)),
      ],
    );
  }
}

class _PosterFan extends StatelessWidget {
  const _PosterFan();

  // Real TMDB posters (interstellar, dune2, parasite, eeaao, la la land),
  // fanned in 4 columns × 2 rows. Reference: `ag-auth.jsx` PosterFan.
  static const String _tmdb = 'https://image.tmdb.org/t/p/w500';
  static const List<List<String>> _cols = <List<String>>[
    ['$_tmdb/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg', '$_tmdb/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg'],
    ['$_tmdb/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg', '$_tmdb/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg'],
    ['$_tmdb/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', '$_tmdb/w3LxiVYdWWRvEVdn5RYq6jIqkb1.jpg'],
    ['$_tmdb/w3LxiVYdWWRvEVdn5RYq6jIqkb1.jpg', '$_tmdb/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg'],
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            height: 360,
            child: Transform.scale(
              scale: 1.25,
              alignment: Alignment.topCenter,
              child: Transform.rotate(
                angle: -0.157,
                child: Opacity(
                  opacity: 0.9,
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: 360,
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < _cols.length; col++)
                          Padding(
                            padding: EdgeInsets.only(left: col == 0 ? 0 : 10, top: col.isOdd ? 28 : 0),
                            child: Column(
                              children: [
                                SizedBox(width: 104, child: AgPoster(imageUrl: _cols[col][0], radius: 12, shadow: false)),
                                const SizedBox(height: 10),
                                SizedBox(width: 104, child: AgPoster(imageUrl: _cols[col][1], radius: 12, shadow: false)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg.withValues(alpha: 0.2), t.bg.withValues(alpha: 0.7), t.bg],
                  stops: const [0, 0.55, 0.92],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 7),
          child: Text(label, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 12.5, color: t.faint)),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          cursorColor: t.red,
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 15.5, color: t.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Manrope', fontSize: 15.5, color: t.faint),
            filled: true,
            fillColor: t.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    onPressed: onToggleObscure,
                    tooltip: 'Toggle password visibility',
                    icon: Icon(AgIcons.eye, size: 19, color: t.faint),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.red, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.redDeep, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.redDeep, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
