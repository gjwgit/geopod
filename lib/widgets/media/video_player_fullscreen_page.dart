/// Fullscreen video page (part of video_player_widget.dart).
///
// Time-stamp: <2026-02-28 GitHub Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

part of 'video_player_widget.dart';

//  Fullscreen video page
/// Self-contained fullscreen page.  Manages its own listener on [controller]
/// and returns [_FullscreenResult] on pop so the caller can sync state.
class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final double initialVolume;
  final double initialSpeed;

  const _FullscreenVideoPage({
    required this.controller,
    required this.initialVolume,
    required this.initialSpeed,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late double _volume;
  late double _preMuteVolume;
  late double _speed;

  /// Subscription to the browser's fullscreenchange stream (web only).
  /// Used to detect when the user exits fullscreen by pressing ESC.
  StreamSubscription<bool>? _fullscreenSub;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume;
    _preMuteVolume = widget.initialVolume > 0 ? widget.initialVolume : 1.0;
    _speed = widget.initialSpeed;
    widget.controller.addListener(_onUpdate);
    // Web: listen for the browser's native fullscreenchange event.
    // When fullscreen == false the user pressed ESC (or F11); we pop.
    _fullscreenSub = systemFullscreenChanges.listen((isFs) {
      if (!isFs && mounted) _exitBySystem();
    });
  }

  @override
  void dispose() {
    _fullscreenSub?.cancel();
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await widget.controller.setVolume(v);
  }

  Future<void> _toggleMute() async {
    if (_volume == 0.0) {
      await _setVolume(_preMuteVolume);
    } else {
      setState(() => _preMuteVolume = _volume);
      await _setVolume(0.0);
    }
  }

  Future<void> _setSpeed(double s) async {
    setState(() => _speed = s);
    await widget.controller.setPlaybackSpeed(s);
  }

  /// Exit button pressed.  Cancel subscription first so that the programmatic
  /// exitSystemFullscreen() call doesn't fire a second _exitBySystem().
  void _exit() {
    _fullscreenSub?.cancel();
    _fullscreenSub = null;
    exitSystemFullscreen(); // no-op on native; on web triggers fullscreenchange
    Navigator.of(
      context,
    ).pop(_FullscreenResult(volume: _volume, speed: _speed));
  }

  /// Browser exited fullscreen (user pressed ESC / F11).
  void _exitBySystem() {
    _fullscreenSub?.cancel();
    _fullscreenSub = null;
    if (mounted) {
      Navigator.of(
        context,
      ).pop(_FullscreenResult(volume: _volume, speed: _speed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final value = ctrl.value;
    final isPlaying = value.isPlaying;
    final duration = value.duration;
    final position = value.position;
    final total = duration.inMilliseconds;
    final current = position.inMilliseconds.clamp(0, total);
    final isMuted = _volume == 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    // Build the fullscreen scaffold first, then on non-web desktop wrap it in
    // a Focus widget so ESC is caught by the Flutter key-event system.
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar  exit button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  tooltip: 'Exit fullscreen',
                  onPressed: _exit,
                ),
                const Spacer(),
              ],
            ),

            // Video surface – fills all available space (no AspectRatio
            // wrapper so the video renderer fills the Expanded area fully).
            Expanded(child: VideoPlayer(ctrl)),

            // Seek bar
            Slider(
              value: current.toDouble(),
              min: 0,
              max: total > 0 ? total.toDouble() : 1,
              activeColor: Colors.white,
              inactiveColor: Colors.white38,
              onChanged: (v) {
                if (total > 0) ctrl.seekTo(Duration(milliseconds: v.toInt()));
              },
            ),

            // Controls row
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Text(
                    fmt(position),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  // Left half  volume
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
                                : _volume < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _toggleMute,
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 80,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white38,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                            ),
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 100,
                              label: '${(_volume * 100).round()}%',
                              onChanged: _setVolume,
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
                      color: Colors.white,
                    ),
                    onPressed: isPlaying ? ctrl.pause : ctrl.play,
                  ),
                  // Right half  speed
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 12),
                        _SpeedButton(
                          currentSpeed: _speed,
                          onSpeedSelected: _setSpeed,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmt(duration),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Web: browser handles ESC natively; we detect it via fullscreenchange.
    // Non-web desktop: wrap with Focus so ESC pops the route.
    if (kIsWeb) return scaffold;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _exit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: scaffold,
    );
  }
}
