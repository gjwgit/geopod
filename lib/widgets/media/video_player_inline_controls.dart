/// Inline video controls widget (part of video_player_widget.dart).
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

part of 'video_player_widget.dart';

//  Inline controls (StatefulWidget so it can listen to the controller)
class _InlineControls extends StatefulWidget {
  final VideoPlayerController controller;
  final double volume;
  final double speed;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onFullscreen;

  const _InlineControls({
    required this.controller,
    required this.volume,
    required this.speed,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onSpeedChanged,
    required this.onFullscreen,
  });

  @override
  State<_InlineControls> createState() => _InlineControlsState();
}

class _InlineControlsState extends State<_InlineControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(_InlineControls old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      _buildControls(context, showFullscreen: true);

  Widget _buildControls(BuildContext context, {required bool showFullscreen}) {
    final ctrl = widget.controller;
    final value = ctrl.value;
    final isPlaying = value.isPlaying;
    final duration = value.duration;
    final position = value.position;
    final total = duration.inMilliseconds;
    final current = position.inMilliseconds.clamp(0, total);
    final volume = widget.volume;
    final speed = widget.speed;
    final isMuted = volume == 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    // Seek bar + controls row together take ~100 px.  When the widget is
    // placed inside a bounded container (e.g. the bottom sheet's
    // ConstrainedBox) we subtract that overhead so the video surface never
    // causes the Column to overflow.
    const double controlsOverhead = 110;

    return LayoutBuilder(
      builder: (context, constraints) {
        final videoMaxHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - controlsOverhead).clamp(40.0, 640.0)
            : 640.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  Video surface
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: videoMaxHeight),
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
            ),

            //  Seek bar
            Slider(
              value: current.toDouble(),
              min: 0,
              max: total > 0 ? total.toDouble() : 1,
              onChanged: (v) {
                if (total > 0) ctrl.seekTo(Duration(milliseconds: v.toInt()));
              },
            ),

            //  Controls row
            // Layout: [time] Expanded([vol ]) [play] Expanded([ speed]) [time] [fs?]
            Row(
              children: [
                const SizedBox(width: 12),
                Text(fmt(position), style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                // Left half  volume right-aligned against play button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: isMuted ? 'Unmute' : 'Mute',
                        icon: Icon(
                          isMuted
                              ? Icons.volume_off
                              : volume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                          size: 18,
                        ),
                        onPressed: widget.onToggleMute,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 80,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                          ),
                          child: Slider(
                            value: volume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 100,
                            label: '${(volume * 100).round()}%',
                            onChanged: widget.onVolumeChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                // Center  play/pause
                IconButton(
                  iconSize: 40,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                  onPressed: isPlaying ? ctrl.pause : ctrl.play,
                ),
                // Right half  speed left-aligned against play button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 12),
                      _SpeedButton(
                        currentSpeed: speed,
                        onSpeedSelected: widget.onSpeedChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(fmt(duration), style: const TextStyle(fontSize: 11)),
                if (showFullscreen) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'Fullscreen',
                    onPressed: widget.onFullscreen,
                  ),
                ],
                const SizedBox(width: 12),
              ],
            ),
          ],
        );
      },
    );
  }
}
