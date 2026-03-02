/// Speed selector popup button (part of video_player_widget.dart).
///
// Time-stamp: <2026-02-28 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

part of 'video_player_widget.dart';

//  Speed selector popup
class _SpeedButton extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;
  final Color? textColor;

  const _SpeedButton({
    required this.currentSpeed,
    required this.onSpeedSelected,
    this.textColor,
  });

  String _label(double s) =>
      s == s.truncateToDouble() ? '${s.toInt()}×' : '$s×';

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Theme.of(context).colorScheme.onSurface;
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: currentSpeed,
      onSelected: onSpeedSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          _label(currentSpeed),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
      itemBuilder: (_) => _kSpeeds
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              child: Text(
                _label(s),
                style: TextStyle(
                  fontWeight: s == currentSpeed
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
