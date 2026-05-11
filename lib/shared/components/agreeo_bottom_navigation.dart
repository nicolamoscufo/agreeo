import 'package:flutter/material.dart';

class AgreeoBottomNavigation extends StatelessWidget {
  const AgreeoBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <_NavItem>[
      _NavItem(label: 'Home', icon: Icons.home),
      _NavItem(label: 'Library', icon: Icons.bookmark),
      _NavItem(label: 'Swipe', icon: Icons.local_fire_department_rounded),
      _NavItem(label: 'Friends', icon: Icons.people),
      _NavItem(
        label: 'Profile',
        icon: Icons.account_circle_outlined,
      ), // or person
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5), // For gradient border
            child: Container(
              decoration: BoxDecoration(
                color: const Color(
                  0xFF1E1E24,
                ).withValues(alpha: 0.95), // dark background
                borderRadius: BorderRadius.circular(22.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(items.length, (index) {
                  final item = items[index];
                  final selected = selectedIndex == index;
                  final centerItem = index == 2;

                  Widget iconRepresentation;
                  if (centerItem) {
                    iconRepresentation = Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Background glow for the flame
                        Positioned(
                          top: 4,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00FFFF,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF00FF,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds);
                          },
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            size: 52, // Large flame
                            color: Colors.white,
                          ),
                        ),
                        const Positioned(
                          bottom: 12,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: Color(
                              0xFF1E1E24,
                            ), // Match bg to look like cutout
                          ),
                        ),
                      ],
                    );
                  } else {
                    iconRepresentation = Icon(
                      item.icon,
                      size: 28,
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    );
                  }

                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: item.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onSelected(index),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              height: 52,
                              child: Center(child: iconRepresentation),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Glowing dot
                            Container(
                              height: 6,
                              width: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF00FFFF,
                                          ).withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: const Color(
                                            0xFFFF00FF,
                                          ).withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
