import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aurora.dart';
import 'glass.dart';
import 'motion.dart';
import 'tokens.dart';

/// The standard content card: a pane of frosted glass. Pass [onTap] and it
/// becomes pressable.
///
/// On the pastel canvas use the default [GlassStyle.light]. On ink or
/// aurora use [GlassStyle.dark] with `blur: Glass.frost`. Pass [gradient]
/// for the rare solid, saturated card.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final GlassStyle style;
  final double blur;
  final Color? tint;
  final Gradient? gradient;
  final bool shadow;
  final String? semanticLabel;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.xl),
    this.radius = AppRadii.lg,
    this.onTap,
    this.style = GlassStyle.light,
    this.blur = 0,
    this.tint,
    this.gradient,
    this.shadow = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final Widget card = gradient != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: borderRadius,
              boxShadow: shadow ? AppShadows.card : null,
            ),
            child: Padding(padding: padding, child: child),
          )
        : Glass(
            style: style,
            blur: blur,
            tint: tint,
            shadow: shadow,
            borderRadius: borderRadius,
            padding: padding,
            child: child,
          );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}

/// An icon sealed in a glossy dome, like a pill in its blister.
class BlisterIcon extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final double size;
  final bool glow;

  const BlisterIcon({
    super.key,
    required this.icon,
    this.tone = Tone.indigo,
    this.size = 52,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: tone.gradient,
          boxShadow: glow ? AppShadows.glow(tone.color, strength: 0.34) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The highlight where light catches the dome.
            Positioned(
              top: size * 0.09,
              left: size * 0.16,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: size * 0.46,
                  height: size * 0.24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Icon(icon, color: Colors.white, size: size * 0.48),
          ],
        ),
      ),
    );
  }
}

/// A flat, tinted icon chip for dense rows where a dome would shout.
class TintIcon extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final double size;

  const TintIcon({
    super.key,
    required this.icon,
    this.tone = Tone.indigo,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: tone.deep, size: size * 0.5),
    );
  }
}

/// Round translucent button for ink surfaces.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool showDot;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 44,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: size * 0.5),
              ),
            ),
            if (showDot)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// A hero area on ink. Handles the status bar and the rounded bottom edge;
/// put the screen's identity and its headline number inside.
class InkHero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;
  final bool safeTop;

  const InkHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.page,
      AppSpace.md,
      AppSpace.page,
      AppSpace.xxl,
    ),
    this.bottomRadius = AppRadii.xl,
    this.safeTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AuroraBackground(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        child: SafeArea(
          top: safeTop,
          bottom: false,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Drop-in replacement for [AppBar] on screens that deserve the ink
/// treatment. Adds a back button on its own when the route can pop.
class InkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final VoidCallback? onBack;

  const InkAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.bottom,
    this.onBack,
  });

  static const double _barHeight = 68;

  @override
  Size get preferredSize => Size.fromHeight(
        _barHeight + (bottom?.preferredSize.height ?? 0) + (bottom == null ? 0 : 8),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    Widget? lead = leading;
    if (lead == null && automaticallyImplyLeading && canPop) {
      lead = GlassIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onTap: onBack ?? () => Navigator.maybePop(context),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AuroraBackground(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.lg),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: Row(
                    children: [
                      if (lead != null) ...[lead, const SizedBox(width: 12)],
                      Expanded(
                        child: titleWidget ??
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.display(
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body(
                                      size: 13,
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                      for (final action in actions) ...[
                        const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
              if (bottom != null) ...[bottom!, const SizedBox(height: 8)],
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's main call to action: a pill that glows in its own colour.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient gradient;
  final Color glowColor;
  final Color foreground;
  final double height;
  final bool expand;

  /// Fill and label colour when [onPressed] is null. The defaults suit the
  /// pastel canvas; the mint variant uses translucent ones for dark glass.
  final Color disabledFill;
  final Color disabledForeground;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.gradient = AppGradients.indigo,
    this.glowColor = AppColors.indigo,
    this.foreground = Colors.white,
    this.height = 56,
    this.expand = true,
    this.disabledFill = AppColors.lineStrong,
    this.disabledForeground = AppColors.textMuted,
  });

  const PrimaryButton.coral({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 56,
    this.expand = true,
  })  : gradient = AppGradients.coral,
        glowColor = AppColors.coral,
        foreground = Colors.white,
        disabledFill = AppColors.lineStrong,
        disabledForeground = AppColors.textMuted;

  const PrimaryButton.mint({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 56,
    this.expand = true,
  })  : gradient = AppGradients.mint,
        glowColor = AppColors.mint,
        foreground = AppColors.ink,
        disabledFill = const Color(0x29FFFFFF),
        disabledForeground = const Color(0x99FFFFFF);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final active = onPressed != null;
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: active ? gradient : null,
          color: active ? null : disabledFill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: active ? AppShadows.glow(glowColor) : const [],
        ),
        foregroundDecoration: active
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55],
                ),
              )
            : null,
        child: Center(
          widthFactor: expand ? null : 1,
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(foreground),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: active ? foreground : disabledForeground,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 16,
                            weight: FontWeight.w700,
                            color: active ? foreground : disabledForeground,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The quieter sibling of [PrimaryButton]: a glass pill. Set [onDark] when
/// it sits on ink or aurora.
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Tone tone;
  final double height;
  final bool expand;
  final bool onDark;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.tone = Tone.indigo,
    this.height = 52,
    this.expand = true,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : tone.deep;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Glass(
        style: onDark ? GlassStyle.dark : GlassStyle.light,
        tint: onDark ? null : Color.lerp(tone.tint, Colors.white, 0.35),
        shadow: false,
        height: height,
        width: expand ? double.infinity : null,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Center(
          widthFactor: expand ? null : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 19),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small status pill.
class TonePill extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  final bool solid;

  const TonePill({
    super.key,
    required this.label,
    this.tone = Tone.indigo,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    // Amber and mint are light: white on them fails contrast, ink does not.
    final lightTone = identical(tone, Tone.amber) || identical(tone, Tone.mint);
    final fg = solid ? (lightTone ? AppColors.ink : Colors.white) : tone.deep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? tone.color : tone.tint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.label(size: 12, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// A two-tone gélule. The brand's smallest unit: used by the loader, the
/// confetti and anywhere a decorative mark is needed.
class Capsule extends StatelessWidget {
  final double width;
  final double height;
  final Color left;
  final Color right;

  const Capsule({
    super.key,
    this.width = 44,
    this.height = 20,
    this.left = AppColors.indigo,
    this.right = AppColors.mint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(child: ColoredBox(color: left)),
                Expanded(child: ColoredBox(color: right)),
              ],
            ),
            Positioned(
              left: height * 0.3,
              right: height * 0.3,
              top: height * 0.16,
              height: height * 0.22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading, in the app's own shape: a capsule that keeps flipping over.
class CapsuleLoader extends StatefulWidget {
  final double size;
  final Color left;
  final Color right;

  const CapsuleLoader({
    super.key,
    this.size = 44,
    this.left = AppColors.indigo,
    this.right = AppColors.mint,
  });

  @override
  State<CapsuleLoader> createState() => _CapsuleLoaderState();
}

class _CapsuleLoaderState extends State<CapsuleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOutBack.transform(_controller.value);
              return Transform.rotate(angle: t * math.pi, child: child);
            },
            child: Capsule(
              width: widget.size,
              height: widget.size * 0.44,
              left: widget.left,
              right: widget.right,
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress drawn as a capsule filling up.
class CapsuleProgress extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final Tone tone;
  final double height;
  final Color? trackColor;

  const CapsuleProgress({
    super.key,
    required this.value,
    this.tone = Tone.indigo,
    this.height = 12,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(target * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          // Always span the available width, even under loose constraints.
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: trackColor ?? tone.tint),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration:
                    AppMotion.reduced(context) ? Duration.zero : AppMotion.hero,
                curve: AppMotion.emphasized,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  alignment: AlignmentDirectional.centerStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(tone.color, Colors.white, 0.25)!,
                          tone.color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(height),
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.5),
                      child: FractionallySizedBox(
                        widthFactor: 0.86,
                        child: Container(
                          height: height * 0.2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(height),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sweeps a highlight over placeholder shapes while content loads.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
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
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: const Alignment(-1, -0.3),
          end: const Alignment(1, 0.3),
          colors: const [
            Color(0xFFE9EAF5),
            Color(0xFFF8F8FD),
            Color(0xFFE9EAF5),
          ],
          stops: const [0.35, 0.5, 0.65],
          transform: _ShimmerSlide(-1 + 2 * _controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _ShimmerSlide extends GradientTransform {
  final double fraction;
  const _ShimmerSlide(this.fraction);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// One placeholder block. Compose several inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadii.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAF5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A ready-made loading state for list screens.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.all(AppSpace.page),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) =>
            SkeletonBox(height: itemHeight, radius: AppRadii.lg),
      ),
    );
  }
}

/// What a screen shows when there is nothing yet. Says what will appear
/// here and, when possible, offers the action that fills it.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Tone tone;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = Tone.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Entrance(
          scaleFrom: 0.94,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: tone.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: tone.deep),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.display(size: 20),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 14, color: AppColors.textMuted),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                PrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  height: 48,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 20),
          ),
        ),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                actionLabel!,
                style: AppText.label(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A round avatar with a gradient ring and an initials fallback.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool ring;
  final Tone tone;

  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.ring = true,
    this.tone = Tone.indigo,
  });

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final inner = size - (ring ? 6 : 0);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final avatar = ClipOval(
      child: SizedBox.square(
        dimension: inner,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: tone.gradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  _initials,
                  style: AppText.display(
                    size: inner * 0.38,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (hasImage)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
    if (!ring) return avatar;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.mintBright, AppColors.indigoBright],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ink,
        ),
        child: avatar,
      ),
    );
  }
}
