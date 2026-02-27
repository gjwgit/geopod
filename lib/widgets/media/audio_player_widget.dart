/// Inline audio playback widget.
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

/// An inline audio player backed by the `video_player` package.
///
/// Uses the same package as [VideoPlayerWidget] so there is no extra native
/// plugin to register  this works on web (HTML5 `<audio>`), Android, iOS,
/// and desktop without any extra setup.
///
/// Supports both bundled assets ([MediaItem.assetPath]) and remote URLs
/// ([MediaItem.remoteUrl]).
class AudioPlayerWidget extends StatefulWidget {
  final MediaItem item;

  const AudioPlayerWidget({super.key, required this.item});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late VideoPlayerController _controller;

  bool _initialized = false;
  bool _failedToLoad = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final item = widget.item;
    try {
      if (item.isRemote) {
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
      debugPrint('[AudioPlayerWidget] init error: $e\n$st');
      if (mounted)
        setState(() {
          _failedToLoad = true;
          _errorMessage = e.toString();
        });
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_failedToLoad) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Audio error: ${_errorMessage ?? 'unknown'}',
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
