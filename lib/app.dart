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
      builder: (context, child) => _CompactPhoneUi(child: child),
      home: const AgreeoBootstrapGate(),
    );
  }
}

class _CompactPhoneUi extends StatelessWidget {
  const _CompactPhoneUi({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final shortestSide = mediaQuery.size.shortestSide;
    if (shortestSide >= 430) {
      return child ?? const SizedBox.shrink();
    }

    const compactScale = 0.92;
    final textScale = (mediaQuery.textScaler.scale(1) * compactScale)
        .clamp(0.88, 1.0)
        .toDouble();
    final scaledChild = MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
      child: child ?? const SizedBox.shrink(),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: scaledChild,
    );
  }
}
