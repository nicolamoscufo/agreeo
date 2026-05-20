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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(items.length, (index) {
                final item = items[index];
                final selected = selectedIndex == index;
                final centerItem = index == 2;

                Widget iconRepresentation;
                if (centerItem) {
                  iconRepresentation = Icon(
                    Icons.local_fire_department_rounded,
                    size: 36,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  );
                } else {
                  iconRepresentation = Icon(
                    item.icon,
                    size: 28,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
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
                            height: 44,
                            child: Center(child: iconRepresentation),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 4,
                            width: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: selected
                                  ? colorScheme.primary
                                  : Colors.transparent,
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
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
