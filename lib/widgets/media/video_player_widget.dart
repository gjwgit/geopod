/// Inline video playback widget.
///
// Time-stamp: <2026-02-28 Miduo>
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

part 'video_player_inline_controls.dart';
part 'video_player_speed_button.dart';
part 'video_player_fullscreen_page.dart';

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
      // Request true browser fullscreen 鈥?browser hides its own chrome and
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
