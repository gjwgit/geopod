/// Inline video playback widget.
///
// Time-stamp: <2026-02-28 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player/video_player.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/utils/fullscreen_stub.dart'
    if (dart.library.html) 'package:geopod/utils/fullscreen_web.dart';

//  Supported playback speeds
const List<double> _kSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Inline video player with seek, play/pause, volume, speed, and fullscreen.
///
/// Supports bundled assets ([MediaItem.assetPath]) and remote URLs
/// ([MediaItem.remoteUrl]) on web, Android, iOS, and desktop.
class VideoPlayerWidget extends StatefulWidget {
  final MediaItem item;

  const VideoPlayerWidget({super.key, required this.item});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  bool _initialized = false;
  bool _failedToLoad = false;
  String? _errorMessage;

  /// Local playback URL for Pod items (Blob URL on web, file:// on native).
  String? _playbackUrl;

  double _volume = 1.0;
  double _preMuteVolume = 1.0;
  double _speed = 1.0;

  /// True while the fullscreen route is on top.  When true the inline
  /// VideoPlayer widget is swapped out for a black placeholder so there is
  /// never more than one VideoPlayer widget in the tree sharing the same
  /// controller.  This prevents texture/renderer corruption on pop.
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_playbackUrl != null) {
      MediaPodService.releasePlaybackUrl(_playbackUrl!);
    }
    super.dispose();
  }

  Future<void> _initVideo() async {
    final item = widget.item;
    try {
      if (item.isPodItem) {
        final url = await MediaPodService.loadPlaybackUrl(item);
        if (url == null) throw Exception('Failed to load media from Pod.');
        _playbackUrl = url;
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (item.isRemote) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(item.remoteUrl!),
        );
      } else {
        _controller = VideoPlayerController.asset(item.assetPath!);
      }
      await _controller.initialize();
      _controller.addListener(_onUpdate);
      if (mounted) setState(() => _initialized = true);
      await _controller.play();
    } catch (e, st) {
      debugPrint('[VideoPlayerWidget] init error: $e\n$st');
      if (mounted) {
        setState(() {
          _failedToLoad = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onUpdate() {
    if (mounted && !_isFullscreen) setState(() {});
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await _controller.setVolume(v);
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
    await _controller.setPlaybackSpeed(s);
  }

  Future<void> _openFullscreen() async {
    if (!mounted) return;

    // 1. Hide inline VideoPlayer BEFORE pushing  avoids two VideoPlayer
    //    widgets sharing the same controller at the same time.
    setState(() => _isFullscreen = true);

    if (kIsWeb) {
      // Request true browser fullscreen – browser hides its own chrome and
      // handles ESC natively.  We listen for fullscreenchange inside
      // _FullscreenVideoPage to detect when ESC is pressed.
      await enterSystemFullscreen();
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (!mounted) {
      if (kIsWeb) await exitSystemFullscreen();
      setState(() => _isFullscreen = false);
      return;
    }

    // 2. Push fullscreen page  it manages its own state and listener.
    final result = await Navigator.of(context).push<_FullscreenResult>(
      MaterialPageRoute<_FullscreenResult>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(
          controller: _controller,
          initialVolume: _volume,
          initialSpeed: _speed,
        ),
      ),
    );

    // 3. Restore system UI / orientation on mobile.
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // 4. Sync volume/speed that may have been changed while fullscreen.
    if (!mounted) return;
    setState(() {
      _isFullscreen = false;
      if (result != null) {
        _volume = result.volume;
        _speed = result.speed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failedToLoad) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Video error: ${_errorMessage ?? 'unknown'}',
          style: const TextStyle(color: Colors.red, fontSize: 11),
        ),
      );
    }
    if (!_initialized) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      );
    }

    // While fullscreen is open, render a black placeholder at the same aspect
    // ratio so the layout does not jump when returning.
    if (_isFullscreen) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: const ColoredBox(color: Colors.black),
      );
    }

    return _InlineControls(
      controller: _controller,
      volume: _volume,
      speed: _speed,
      onVolumeChanged: _setVolume,
      onToggleMute: _toggleMute,
      onSpeedChanged: _setSpeed,
      onFullscreen: _openFullscreen,
    );
  }
}

//  Simple data class returned by the fullscreen page on pop
class _FullscreenResult {
  final double volume;
  final double speed;
  const _FullscreenResult({required this.volume, required this.speed});
}

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        //  Video surface – capped at 240 px tall so it fits in the card
        //  without the user needing to scroll.  Full-screen removes this cap.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 640),
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
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
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
  }
}

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
