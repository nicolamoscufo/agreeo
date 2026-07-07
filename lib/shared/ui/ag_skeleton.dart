import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';

/// Loading-state primitives for the Daylight system. A [AgSkeletonBox] is a
/// single placeholder block; wrap a group of them in [AgShimmer] to sweep one
/// shared highlight band across the whole group.
///
/// Why a distinct loading vocabulary: the app's rails fall back to `surface`
/// cards that look identical whether data is *loading* or genuinely *empty*.
/// Skeletons make "still loading" legible so a slow feed never reads as broken.
///
/// Motion is reduced-motion aware: when the platform requests reduced motion
/// (`MediaQuery.disableAnimations`), [AgShimmer] renders the static skeleton
/// with no sweep instead of animating.

/// A single rounded placeholder block in the neutral skeleton tone.
class AgSkeletonBox extends StatelessWidget {
  const AgSkeletonBox({super.key, this.width, this.height, this.radius = 12});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Sweeps a single soft highlight band across [child] to signal loading.
/// Honors reduced-motion by rendering [child] statically.
class AgShimmer extends StatefulWidget {
  const AgShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AgShimmer> createState() => _AgShimmerState();
}

class _AgShimmerState extends State<AgShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: show the static skeleton, no sweep.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final t = context.tokens;
    final highlight = Color.alphaBlend(
      t.text.withValues(alpha: 0.07),
      t.surface2,
    );

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [t.surface2, highlight, t.surface2],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideTransform(_controller.value * 2 - 1),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.slide);

  final double slide;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}

/// Loading placeholder for a horizontal poster rail. Mirrors the geometry of the
/// real rail (2:3 posters at [posterWidth], optional meta line) so the swap from
/// loading to loaded doesn't shift layout.
class AgPosterRailSkeleton extends StatelessWidget {
  const AgPosterRailSkeleton({
    super.key,
    required this.posterWidth,
    this.showMeta = false,
    this.count = 4,
  });

  final double posterWidth;
  final bool showMeta;
  final int count;

  @override
  Widget build(BuildContext context) {
    final posterHeight = posterWidth * 1.5;
    final height = posterHeight + (showMeta ? 30 : 0);
    return Semantics(
      label: 'Loading',
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: AgShimmer(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, _) {
                return SizedBox(
                  width: posterWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AgSkeletonBox(
                        width: posterWidth,
                        height: posterHeight,
                        radius: 14,
                      ),
                      if (showMeta) ...[
                        const SizedBox(height: 11),
                        AgSkeletonBox(width: posterWidth * 0.6, height: 11),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder for a poster grid (e.g. search results). Mirrors the
/// 3-column, 2:3 grid so the loaded results drop in without a reflow.
class AgPosterGridSkeleton extends StatelessWidget {
  const AgPosterGridSkeleton({
    super.key,
    this.crossAxisCount = 3,
    this.count = 6,
  });

  final int crossAxisCount;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: ExcludeSemantics(
        child: AgShimmer(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2 / 3,
            ),
            itemBuilder: (context, _) => const AgSkeletonBox(radius: 14),
          ),
        ),
      ),
    );
  }
}
