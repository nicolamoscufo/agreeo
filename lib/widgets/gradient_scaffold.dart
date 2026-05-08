import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.child,
    this.extendBodyBehindAppBar = true,
    this.floatingActionButton,
  });

  final Widget child;
  final bool extendBodyBehindAppBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.10),
              colorScheme.surface,
              colorScheme.tertiary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
