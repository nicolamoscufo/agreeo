import 'package:agreeo/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: Firebase initialization is skipped as configuration options are not available
  // for this local web environment, preventing an assertion error on the platform.
  // For production use, please run 'flutterfire configure'.

  runApp(const ProviderScope(child: AgreeoApp()));
}
