import 'package:agreeo/features/bootstrap/presentation/agreeo_bootstrap_gate.dart';
import 'package:agreeo/shared/theme/agreeo_theme.dart';
import 'package:flutter/material.dart';

class AgreeoApp extends StatelessWidget {
  const AgreeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agreeo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildAgreeoTheme(Brightness.light),
      darkTheme: buildAgreeoTheme(Brightness.dark),
      home: const AgreeoBootstrapGate(),
    );
  }
}
