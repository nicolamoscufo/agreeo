import 'package:agreeo/shared/components/primitives.dart';
import 'package:flutter/material.dart';

class FriendsPlaceholderScreen extends StatelessWidget {
  const FriendsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            SectionHeader(
              title: 'Friends',
              subtitle:
                  'Phase 2 will add friend search, requests, profiles, and movie night coordination.',
            ),
            SizedBox(height: 18),
            Expanded(
              child: EmptyState(
                icon: Icons.groups_rounded,
                title: 'Social features start next phase',
                message:
                    'The tab is already reserved in navigation, but friend graphs and Movie Nights are intentionally still blocked until Phase 1 is fully stable.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
