import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.file, required this.title});

  final File file;
  final String title;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _locked = false;
  bool _controlsVisible = true;
  double _zoom = 1;
  double _startZoom = 1;
  Duration? _dragPreview;
  double? _startBrightness;
  double? _startVolume;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true),
    );
    _player.open(Media(Uri.file(widget.file.path).toString()));
  }

  @override
  void dispose() {
    ScreenBrightness.instance.resetApplicationScreenBrightness();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _pickSubtitle() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'ass', 'ssa', 'vtt', 'sub', 'smi'],
    );
    final path = selected?.path;
    if (path == null) return;
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(Uri.file(path).toString(), title: selected!.name),
    );
  }

  Future<void> _saveScreenshot() async {
    final Uint8List? bytes = await _player.screenshot(format: 'image/jpeg');
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}aman_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ لقطة مؤقتة: ${file.path}')),
    );
  }

  Future<void> _showSpeedSheet() async {
    final rate = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map(
                  (e) => ActionChip(
                    label: Text('${e}x'),
                    onPressed: () => Navigator.pop(context, e),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (rate != null) await _player.setRate(rate);
  }

  Future<void> _showTracksSheet() async {
    final audio = _player.state.tracks.audio;
    final subtitles = _player.state.tracks.subtitle;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            const ListTile(title: Text('المسارات الصوتية', style: TextStyle(fontWeight: FontWeight.bold))),
            ...audio.map(
              (track) => ListTile(
                leading: const Icon(Icons.graphic_eq_rounded),
                title: Text(track.title ?? track.language ?? 'مسار صوتي'),
                subtitle: Text(track.codec ?? ''),
                onTap: () async {
                  await _player.setAudioTrack(track);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.subtitles_off_outlined),
              title: const Text('إيقاف الترجمة'),
              onTap: () async {
                await _player.setSubtitleTrack(SubtitleTrack.no());
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ...subtitles.map(
              (track) => ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(track.title ?? track.language ?? 'ترجمة'),
                subtitle: Text(track.codec ?? ''),
                onTap: () async {
                  await _player.setSubtitleTrack(track);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seekBy(Duration delta) async {
    final duration = _player.state.duration;
    var target = _player.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_locked) return;
                setState(() => _controlsVisible = !_controlsVisible);
              },
              onDoubleTapDown: (details) {
                if (_locked) return;
                final left = details.localPosition.dx < constraints.maxWidth / 2;
                _seekBy(Duration(seconds: left ? -10 : 10));
              },
              onScaleStart: (details) {
                if (_locked) return;
                _startZoom = _zoom;
              },
              onScaleUpdate: (details) {
                if (_locked || details.pointerCount < 2) return;
                setState(() => _zoom = (_startZoom * details.scale).clamp(0.8, 3.0).toDouble());
              },
              onHorizontalDragStart: (_) {
                if (_locked) return;
                _dragPreview = _player.state.position;
              },
              onHorizontalDragUpdate: (details) {
                if (_locked || _dragPreview == null) return;
                final duration = _player.state.duration;
                if (duration <= Duration.zero) return;
                final deltaMs = (details.delta.dx / constraints.maxWidth * 90000).round();
                var next = _dragPreview! + Duration(milliseconds: deltaMs);
                if (next < Duration.zero) next = Duration.zero;
                if (next > duration) next = duration;
                setState(() => _dragPreview = next);
              },
              onHorizontalDragEnd: (_) async {
                if (_locked || _dragPreview == null) return;
                final target = _dragPreview!;
                setState(() => _dragPreview = null);
                await _player.seek(target);
              },
              onVerticalDragStart: (details) async {
                if (_locked) return;
                if (details.localPosition.dx < constraints.maxWidth / 2) {
                  _startBrightness = await ScreenBrightness.instance.application;
                } else {
                  _startVolume = _player.state.volume;
                }
              },
              onVerticalDragUpdate: (details) async {
                if (_locked) return;
                final delta = -details.delta.dy / constraints.maxHeight;
                if (details.localPosition.dx < constraints.maxWidth / 2) {
                  final start = _startBrightness ?? await ScreenBrightness.instance.application;
                  final next = (start + delta).clamp(0.02, 1.0).toDouble();
                  _startBrightness = next;
                  await ScreenBrightness.instance.setApplicationScreenBrightness(next);
                } else {
                  final start = _startVolume ?? _player.state.volume;
                  final next = (start + delta * 100).clamp(0.0, 100.0).toDouble();
                  _startVolume = next;
                  await _player.setVolume(next);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.scale(
                      scale: _zoom,
                      child: Video(
                        controller: _controller,
                        fit: BoxFit.contain,
                        controls: NoVideoControls,
                        subtitleViewConfiguration: const SubtitleViewConfiguration(
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.35,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                          ),
                          textAlign: TextAlign.center,
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 42),
                        ),
                      ),
                    ),
                  ),
                  if (_dragPreview != null)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Text(
                            _fmt(_dragPreview!),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  if (_controlsVisible || _locked) _buildControls(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              if (!_locked) ...[
                IconButton(
                  tooltip: 'لقطة شاشة',
                  color: Colors.white,
                  onPressed: _saveScreenshot,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                PopupMenuButton<String>(
                  color: Theme.of(context).colorScheme.surface,
                  iconColor: Colors.white,
                  onSelected: (value) {
                    if (value == 'subtitle') _pickSubtitle();
                    if (value == 'tracks') _showTracksSheet();
                    if (value == 'speed') _showSpeedSheet();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'subtitle', child: Text('إضافة ترجمة خارجية')),
                    PopupMenuItem(value: 'tracks', child: Text('الصوت والترجمة')),
                    PopupMenuItem(value: 'speed', child: Text('سرعة التشغيل')),
                  ],
                ),
              ],
            ],
          ),
        ),
        Center(
          child: _locked
              ? IconButton.filledTonal(
                  onPressed: () => setState(() => _locked = false),
                  icon: const Icon(Icons.lock_rounded),
                )
              : StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  initialData: _player.state.playing,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          color: Colors.white,
                          iconSize: 34,
                          onPressed: () => _seekBy(const Duration(seconds: -10)),
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: 16),
                        IconButton.filled(
                          iconSize: 42,
                          onPressed: _player.playOrPause,
                          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          color: Colors.white,
                          iconSize: 34,
                          onPressed: () => _seekBy(const Duration(seconds: 10)),
                          icon: const Icon(Icons.forward_10_rounded),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (!_locked)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: StreamBuilder<Duration>(
                stream: _player.stream.position,
                initialData: _player.state.position,
                builder: (context, posSnapshot) {
                  return StreamBuilder<Duration>(
                    stream: _player.stream.duration,
                    initialData: _player.state.duration,
                    builder: (context, durSnapshot) {
                      final position = posSnapshot.data ?? Duration.zero;
                      final duration = durSnapshot.data ?? Duration.zero;
                      final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                      final value = position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            value: value,
                            max: maxMs,
                            onChanged: (v) => _player.seek(Duration(milliseconds: v.round())),
                          ),
                          Row(
                            children: [
                              Text(_fmt(position), style: const TextStyle(color: Colors.white)),
                              const Text(' / ', style: TextStyle(color: Colors.white70)),
                              Text(_fmt(duration), style: const TextStyle(color: Colors.white70)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'قفل الشاشة',
                                color: Colors.white,
                                onPressed: () => setState(() => _locked = true),
                                icon: const Icon(Icons.lock_open_rounded),
                              ),
                              IconButton(
                                tooltip: 'ملء الشاشة/التكبير',
                                color: Colors.white,
                                onPressed: () => setState(() => _zoom = _zoom == 1 ? 1.15 : 1),
                                icon: const Icon(Icons.aspect_ratio_rounded),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
