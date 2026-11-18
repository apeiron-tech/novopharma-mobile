/// Capsule — the MyChallenge design system.
///
/// Import this one file from screens:
///
/// ```dart
/// import 'package:novopharma/design/design.dart';
/// ```
///
/// How a screen is put together
///  * Everything is glass. Content screens rest on [AppBackground] (a
///    pastel wash) and hold their content in [SoftCard]s — frosted panes
///    with a lit rim. Vary their size and weight with what they hold.
///  * Identity on ink: hero screens open with [InkHero] (or [InkAppBar] in
///    a Scaffold), one per screen. On ink, cards are
///    `SoftCard(style: GlassStyle.dark, blur: Glass.frost)` with white text.
///  * Real blur ([Glass.blur] > 0) is for panes that float over detail or
///    motion: the dock, sheets ([GlassSheet]), dialogs ([showGlassDialog]),
///    cards on the aurora. Cards on the pastel canvas need none.
///  * One accent per feature via [Tone]: peach = sales, mint = ranking and
///    gains, coral = objectives and spending, amber = badges and rewards,
///    indigo = challenges and everything brand.
///  * Headlines and every number in [AppText.display]; reading text in
///    [AppText.body]; small captions in [AppText.label].
///  * Shared controls: [AppSearchField], [SegmentedTabs], [SelectPill],
///    [GlassBottomBar], [StatBlock], [PrimaryButton], [SecondaryButton].
///  * The logo is code: [BrandMark], [BrandLogo], [BrandTile].
///
/// How it moves
///  * Anything tappable goes through [Pressable] (or a button built on it).
///  * One arrival sequence per screen with [Entrance] / [Entrance.staggered].
///  * Numbers that matter roll with [CountUp]; progress fills with
///    [CapsuleProgress].
///  * Loading uses [CapsuleLoader] or a [Shimmer] of [SkeletonBox]es.
///  * [celebrate] is for earned wins only.
library;

export 'aurora.dart';
export 'brand.dart';
export 'celebration.dart';
export 'controls.dart';
export 'glass.dart';
export 'motion.dart';
export 'surfaces.dart';
export 'tokens.dart';
