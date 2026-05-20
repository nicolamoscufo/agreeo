import 'dart:async';

import 'package:agreeo/features/bootstrap/presentation/agreeo_bootstrap_gate.dart';
import 'package:agreeo/shared/state/movie_night_invite_provider.dart';
import 'package:agreeo/shared/theme/agreeo_theme.dart';
import 'package:agreeo/shared/utils/movie_night_invite_links.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoApp extends ConsumerStatefulWidget {
  const AgreeoApp({super.key});

  @override
  ConsumerState<AgreeoApp> createState() => _AgreeoAppState();
}

class _AgreeoAppState extends ConsumerState<AgreeoApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      _handleDeepLink(await _appLinks.getInitialLink());
    } catch (error) {
      debugPrint('Error reading initial invite link: $error');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (Object error) {
        debugPrint('Error reading invite link stream: $error');
      },
    );
  }

  void _handleDeepLink(Uri? uri) {
    final eventId = movieNightInviteEventIdFromUri(uri);
    if (eventId == null) {
      return;
    }
    ref.read(pendingMovieNightInviteProvider.notifier).state = eventId;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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
