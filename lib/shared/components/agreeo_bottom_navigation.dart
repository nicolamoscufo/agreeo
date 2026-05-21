import 'package:flutter/material.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';


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
                  iconRepresentation = PopcornIcon(selected: selected);
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

class PopcornIcon extends StatelessWidget {
  const PopcornIcon({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: selected ? 1.0 : 0.9,
        end: selected ? 1.15 : 0.9,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: const Size(36, 36),
            painter: PopcornPainter(selected: selected),
          ),
        );
      },
    );
  }
}

class PopcornPainter extends CustomPainter {
  const PopcornPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Paints
    final redPaint = Paint()
      ..color = AgreeoColors.cinematicRed.withValues(alpha: selected ? 1.0 : 0.5)
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = AgreeoColors.popcornWhite.withValues(alpha: selected ? 1.0 : 0.5)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = AgreeoColors.kernelGold.withValues(alpha: selected ? 1.0 : 0.5)
      ..style = PaintingStyle.fill;

    final lightGoldPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: selected ? 1.0 : 0.5) // Lighter gold
      ..style = PaintingStyle.fill;

    final shadowGoldPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: selected ? 1.0 : 0.5) // Shaded gold
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: selected ? 1.0 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final facePaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: selected ? 1.0 : 0.4)
      ..style = PaintingStyle.fill;

    // 1. Popcorn kernels (overlapping circles)
    // Left
    canvas.drawCircle(Offset(w * 0.32, h * 0.32), w * 0.14, shadowGoldPaint);
    canvas.drawCircle(Offset(w * 0.32, h * 0.32), w * 0.12, goldPaint);
    canvas.drawCircle(Offset(w * 0.28, h * 0.28), w * 0.06, lightGoldPaint);

    // Right
    canvas.drawCircle(Offset(w * 0.68, h * 0.32), w * 0.14, shadowGoldPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.32), w * 0.12, goldPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.28), w * 0.06, lightGoldPaint);

    // Middle-left
    canvas.drawCircle(Offset(w * 0.42, h * 0.24), w * 0.15, shadowGoldPaint);
    canvas.drawCircle(Offset(w * 0.42, h * 0.24), w * 0.13, goldPaint);
    canvas.drawCircle(Offset(w * 0.38, h * 0.20), w * 0.07, lightGoldPaint);

    // Middle-right
    canvas.drawCircle(Offset(w * 0.58, h * 0.24), w * 0.15, shadowGoldPaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.24), w * 0.13, goldPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.20), w * 0.07, lightGoldPaint);

    // Top-center
    canvas.drawCircle(Offset(w * 0.50, h * 0.15), w * 0.14, shadowGoldPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.15), w * 0.12, goldPaint);
    canvas.drawCircle(Offset(w * 0.47, h * 0.12), w * 0.06, lightGoldPaint);

    // Outlines for popcorn
    canvas.drawCircle(Offset(w * 0.32, h * 0.32), w * 0.12, strokePaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.32), w * 0.12, strokePaint);
    canvas.drawCircle(Offset(w * 0.42, h * 0.24), w * 0.13, strokePaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.24), w * 0.13, strokePaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.15), w * 0.12, strokePaint);

    // 2. Bucket (trapezoid)
    final bucketPath = Path()
      ..moveTo(w * 0.20, h * 0.40)
      ..lineTo(w * 0.80, h * 0.40)
      ..lineTo(w * 0.70, h * 0.88)
      ..lineTo(w * 0.30, h * 0.88)
      ..close();

    canvas.drawPath(bucketPath, whitePaint);

    canvas.save();
    canvas.clipPath(bucketPath);

    // Draw red stripes
    void drawStripe(double startPct, double endPct) {
      final stripePath = Path()
        ..moveTo(w * (0.20 + startPct * 0.60), h * 0.40)
        ..lineTo(w * (0.20 + endPct * 0.60), h * 0.40)
        ..lineTo(w * (0.30 + endPct * 0.40), h * 0.88)
        ..lineTo(w * (0.30 + startPct * 0.40), h * 0.88)
        ..close();
      canvas.drawPath(stripePath, redPaint);
    }

    drawStripe(0.12, 0.28);
    drawStripe(0.42, 0.58);
    drawStripe(0.72, 0.88);

    canvas.restore();

    canvas.drawPath(bucketPath, strokePaint);

    // 3. Smiley face
    final eyeRadius = w * 0.035;
    canvas.drawCircle(Offset(w * 0.42, h * 0.62), eyeRadius, facePaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.62), eyeRadius, facePaint);

    // Blushing cheeks
    final cheekPaint = Paint()
      ..color = const Color(0xFFFF8A80).withValues(alpha: selected ? 0.8 : 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.35, h * 0.66), w * 0.03, cheekPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.66), w * 0.03, cheekPaint);

    // Smile mouth
    final mouthRect = Rect.fromLTWH(w * 0.46, h * 0.60, w * 0.08, h * 0.08);
    final mouthPath = Path()..addArc(mouthRect, 0.1, 2.9);
    canvas.drawPath(mouthPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant PopcornPainter oldDelegate) =>
      oldDelegate.selected != selected;
}
