import 'package:agreeo/shared/services/mock_auth_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

enum _AuthMode { signUp, logIn }

class AgreeoAuthWelcomeScreen extends ConsumerStatefulWidget {
  const AgreeoAuthWelcomeScreen({super.key});

  @override
  ConsumerState<AgreeoAuthWelcomeScreen> createState() =>
      _AgreeoAuthWelcomeScreenState();
}

class _AgreeoAuthWelcomeScreenState
    extends ConsumerState<AgreeoAuthWelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  _AuthMode _mode = _AuthMode.logIn;

  bool get _isSignUp => _mode == _AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _isSignUp ? _AuthMode.logIn : _AuthMode.signUp;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final controller = ref.read(agreeoAppControllerProvider.notifier);
      if (_isSignUp) {
        await controller.signUp(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await controller.logIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on MockAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ), // subtract padding
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      // Neon Text Logo
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Testo sfocato per l'alone / glow
                            Text(
                              'Agreeo',
                              style: GoogleFonts.pacifico(
                                fontSize: 72,
                                fontWeight: FontWeight.normal,
                                foreground: Paint()
                                  ..shader =
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFC026D3),
                                          Color(0xFF22D3EE),
                                        ],
                                      ).createShader(
                                        const Rect.fromLTWH(0, 0, 200, 70),
                                      )
                                  ..maskFilter = const MaskFilter.blur(
                                    BlurStyle.normal,
                                    12,
                                  ),
                              ),
                            ),
                            // Testo in primo piano nitido
                            Text(
                              'Agreeo',
                              style: GoogleFonts.pacifico(
                                fontSize: 72,
                                fontWeight: FontWeight.normal,
                                foreground: Paint()
                                  ..shader =
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFE879F9),
                                          Color(0xFF67E8F9),
                                        ],
                                      ).createShader(
                                        const Rect.fromLTWH(0, 0, 200, 70),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: _buildInputDecoration('Name'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _emailController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: _buildInputDecoration('Email'),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: _buildInputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Neon Login Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC026D3), Color(0xFF22D3EE)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x60C026D3),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ), // Glow effect
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: _submitting ? null : _submit,
                            child: Center(
                              child: _submitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      _isSignUp ? 'Sign Up' : 'Log In',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Bottom Switch Mode
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20, top: 40),
                        child: GestureDetector(
                          onTap: _toggleMode,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: RichText(
                              text: TextSpan(
                                text: _isSignUp
                                    ? 'Already have an account? '
                                    : 'Don\'t have an account? ',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isSignUp ? 'Log in' : 'Sign up',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
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
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 16),
      filled: true,
      fillColor: const Color(0xFF232325),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 1.5),
      ),
    );
  }
}
