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
    final colorScheme = Theme.of(context).colorScheme;
    const items = <_NavItem>[
      _NavItem(label: 'Home', icon: Icons.home_rounded),
      _NavItem(label: 'Library', icon: Icons.bookmark_rounded),
      _NavItem(label: 'Swipe', icon: Icons.local_fire_department_rounded),
      _NavItem(label: 'Friends', icon: Icons.groups_rounded),
      _NavItem(label: 'Profile', icon: Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: List<Widget>.generate(items.length, (index) {
            final item = items[index];
            final selected = selectedIndex == index;
            final centerItem = index == 2;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: centerItem ? 42 : 34,
                          height: centerItem ? 42 : 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: centerItem
                                ? LinearGradient(
                                    colors: <Color>[
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  )
                                : null,
                            color: !centerItem && selected
                                ? colorScheme.primary.withValues(alpha: 0.18)
                                : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            item.icon,
                            size: centerItem ? 21 : 19,
                            color: centerItem
                                ? Colors.white
                                : selected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected || centerItem
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                            fontWeight: selected || centerItem
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
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
