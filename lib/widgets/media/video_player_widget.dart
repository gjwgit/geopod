/// Inline video playback widget.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:video_player/video_player.dart';

import 'package:geopod/models/media_item.dart';

/// An inline video player backed by the `video_player` package.
///
/// Supports both bundled assets ([MediaItem.assetPath]) and remote URLs
/// ([MediaItem.remoteUrl]) on all platforms (web, Android, iOS, desktop).
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

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final item = widget.item;
    try {
      if (item.isRemote) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(item.remoteUrl!),
        );
      } else {
        // VideoPlayerController.asset() accepts the full Flutter asset key,
        // e.g. 'assets/video/example1.mp4', matching pubspec.yaml declaration.
        _controller = VideoPlayerController.asset(item.assetPath!);
      }

      await _controller.initialize();
      _controller.addListener(_onControllerUpdate);
      if (mounted) setState(() => _initialized = true);

      // Auto-play on expand.
      await _controller.play();
    } catch (e, st) {
      debugPrint('[VideoPlayerWidget] init error: $e\n$st');
      if (mounted)
        setState(() {
          _failedToLoad = true;
          _errorMessage = e.toString();
        });
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
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

    final isPlaying = _controller.value.isPlaying;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final total = duration.inMilliseconds;
    final current = position.inMilliseconds.clamp(0, total);

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Slider(
          value: current.toDouble(),
          min: 0,
          max: total > 0 ? total.toDouble() : 1,
          onChanged: (v) {
            if (total > 0) {
              _controller.seekTo(Duration(milliseconds: v.toInt()));
            }
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(fmt(position), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            IconButton(
              iconSize: 36,
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: isPlaying ? _controller.pause : _controller.play,
            ),
            const SizedBox(width: 12),
            Text(fmt(duration), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
