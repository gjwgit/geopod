/// Inline audio playback widget.
///
// Time-stamp: <2026-02-27 Miduo>
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
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';

/// An inline audio player backed by the `video_player` package.
///
/// Features: seek slider, play/pause, volume control (mute toggle + slider).
/// Works on web (HTML5 `<audio>`), Android, iOS, and desktop without extra setup.
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

  /// Local playback URL created by [MediaPodService.loadPlaybackUrl] for Pod
  /// items.  Must be released in [dispose] to free the underlying Blob / temp
  /// file.
  String? _playbackUrl;

  double _volume = 1.0;
  double _preMuteVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_playbackUrl != null) {
      MediaPodService.releasePlaybackUrl(_playbackUrl!);
    }
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final item = widget.item;
    try {
      // Check security key for encrypted media before attempting playback
      if (item.isPodItem && item.isEncrypted) {
        if (!mounted) return;
        final hasKey = await EncryptedPlacesService.ensureSecurityKey(
          context,
          widget,
        );
        if (!hasKey) {
          throw Exception('Security key required for encrypted media');
        }
      }

      if (item.isPodItem) {
        // Download (and optionally decrypt) the file, get a local playback URL.
        final url = await MediaPodService.loadPlaybackUrl(item);
        if (url == null) {
          throw Exception('Failed to load media from Pod.');
        }
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
      debugPrint('[AudioPlayerWidget] init error: $e\n$st');
      if (mounted) {
        setState(() {
          _failedToLoad = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
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

    final isMuted = _volume == 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        //  Seek bar
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

        // ── Controls: time | [vol →] | ⏸ | [← empty] | time ────────────────
        // Wrapped in LayoutBuilder to hide the fixed-width volume slider on
        // narrow screens and prevent bottom overflow.
        LayoutBuilder(
          builder: (context, constraints) {
            final showVolumeSlider = constraints.maxWidth >= 360;
            final showVolumeIcon = constraints.maxWidth >= 280;
            return Row(
              children: [
                const SizedBox(width: 12),
                Text(fmt(position), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                // Left half – volume, right-aligned to hug play button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showVolumeIcon) ...[
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
                          ),
                          onPressed: _toggleMute,
                        ),
                        if (showVolumeSlider) ...[
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
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                divisions: 100,
                                label: '${(_volume * 100).round()}%',
                                onChanged: _setVolume,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
                // Center – play/pause
                IconButton(
                  iconSize: 40,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                  onPressed: isPlaying ? _controller.pause : _controller.play,
                ),
                // Right half – mirror spacer (keeps play centred)
                const Expanded(child: SizedBox.shrink()),
                const SizedBox(width: 8),
                Text(fmt(duration), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
              ],
            );
          },
        ),
      ],
    );
  }
}
