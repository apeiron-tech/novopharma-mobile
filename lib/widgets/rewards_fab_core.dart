import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

/// Standalone Rewards button: the gift sealed in an amber dome (amber is the
/// colour of points and rewards). Sinks under the finger like every other
/// control and opens the rewards screen.
class RewardsFABCore extends StatefulWidget {
  const RewardsFABCore({super.key});

  @override
  State<RewardsFABCore> createState() => _RewardsFABCoreState();
}

class _RewardsFABCoreState extends State<RewardsFABCore> {
  void _onTap() {
    Navigator.of(context).pushNamed('/rewards');
  }

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)?.redeemYourPoints;
    final button = Pressable(
      onTap: _onTap,
      pressedScale: 0.92,
      semanticLabel: label,
      child: Container(
        width: 64,
        height: 64,
        // A hairline of light around the dome so it reads as glass when it
        // floats over content.
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: const BlisterIcon(
          icon: Icons.card_giftcard_rounded,
          tone: Tone.amber,
          size: 64,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: label == null ? button : Tooltip(message: label, child: button),
    );
  }
}
