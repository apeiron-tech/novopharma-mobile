import 'package:flutter/material.dart';

import 'glass.dart';
import 'motion.dart';
import 'tokens.dart';

/// A search field as a glass pill. Set [onDark] when it sits on ink.
class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool onDark;
  final FocusNode? focusNode;
  final Widget? trailing;

  const AppSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onDark = false,
    this.focusNode,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.text;
    final soft = onDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textFaint;
    return Glass(
      style: onDark ? GlassStyle.dark : GlassStyle.light,
      shadow: !onDark,
      height: 52,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.only(left: 18, right: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: soft, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: onDark ? AppColors.mintBright : AppColors.indigo,
              style: AppText.body(size: 15.5, color: fg, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppText.body(size: 15.5, color: soft),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (controller != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 12)
                  : IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      icon: Icon(Icons.close_rounded, color: soft, size: 20),
                      onPressed: () {
                        controller!.clear();
                        onChanged?.call('');
                        onClear?.call();
                      },
                    ),
            )
          else
            const SizedBox(width: 12),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A segmented control: a glass track with a thumb that springs to the
/// selected segment. For two to four short labels.
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool onDark;
  final double height;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.onDark = false,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final count = labels.length;
    final index = selectedIndex.clamp(0, count - 1);
    final thumbColor = onDark ? Colors.white : AppColors.indigo;
    final selectedText = onDark ? AppColors.ink : Colors.white;
    final idleText =
        onDark ? Colors.white.withValues(alpha: 0.78) : AppColors.textMuted;

    return Glass(
      style: onDark ? GlassStyle.dark : GlassStyle.light,
      shadow: false,
      height: height,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppMotion.medium,
            curve: AppMotion.spring,
            alignment: Alignment(
              count == 1 ? 0 : -1 + 2 * index / (count - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thumbColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: onDark
                      ? null
                      : AppShadows.glow(AppColors.indigo, strength: 0.3),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Pressable(
                    pressedScale: 0.95,
                    semanticLabel: labels[i],
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: AppMotion.fast,
                        style: AppText.label(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: i == index ? selectedText : idleText,
                          letterSpacing: 0,
                        ),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A selectable filter pill. Use in a horizontal list for categories.
class SelectPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Tone tone;

  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.tone = Tone.indigo,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? tone.color : Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow:
              selected ? AppShadows.glow(tone.color, strength: 0.3) : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.label(
                size: 13.5,
                weight: FontWeight.w700,
                color: fg,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A frosted bar pinned to the bottom of a screen for its main action
/// (confirm a sale, submit a quiz). Use as `Scaffold.bottomNavigationBar`
/// with `extendBody: true` so the page scrolls underneath it.
class GlassBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: Glass.frost,
      shadow: false,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.lg),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A label over a large figure. For summaries and stat rows.
class StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool onDark;
  final Tone? tone;
  final CrossAxisAlignment alignment;

  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.onDark = false,
    this.tone,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor =
        tone?.deep ?? (onDark ? Colors.white : AppColors.text);
    final labelColor =
        onDark ? Colors.white.withValues(alpha: 0.74) : AppColors.textMuted;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.label(size: 12.5, color: labelColor, letterSpacing: 0),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AppText.display(size: 24, color: valueColor)),
        ),
      ],
    );
  }
}
