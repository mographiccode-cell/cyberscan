import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = PlatformDispatcher.instance.defaultRouteName;
  final initialUri = route == '/' ? null : Uri.tryParse(route);
  runApp(AmanPlayerApp(initialUri: initialUri));
}

class AmanPlayerApp extends StatelessWidget {
  const AmanPlayerApp({super.key, this.initialUri});

  final Uri? initialUri;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF16B7A7);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أمان بلاير',
      initialRoute: '/',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101214),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: initialUri == null
            ? const HomePage()
            : PlayerPage(uri: initialUri!),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أمان بلاير',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'مشغل فيديو محلي وآمن',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 54,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'أمان بلاير',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لتشغيل فيديو: افتح مدير الملفات أو الاستديو، اضغط على الفيديو، ثم اختر «فتح باستخدام» واختر أمان بلاير.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'التشغيل محلي فقط — لا يتم رفع الفيديو إلى الإنترنت.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'تصميم وبرمجة م.محمود دغَبس',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.uri});

  final Uri uri;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _locked = false;
  bool _controlsVisible = true;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final VideoPlayerController controller;
      if (widget.uri.scheme == 'file') {
        controller = VideoPlayerController.file(
          File(widget.uri.toFilePath()),
        );
      } else {
        controller = VideoPlayerController.contentUri(widget.uri);
      }
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.uri.pathSegments.isEmpty) return 'فيديو محلي';
    final value = Uri.decodeComponent(widget.uri.pathSegments.last);
    return value.isEmpty ? 'فيديو محلي' : value;
  }

  String _time(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : value.inMinutes.toString() + ':' + s;
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null) return;
    final current = controller.value.position;
    final duration = controller.value.duration;
    var target = current + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    await controller.seekTo(target);
  }

  Future<void> _changeSpeed(double value) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setPlaybackSpeed(value);
    if (mounted) setState(() => _speed = value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _errorView()
            : controller == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, box) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_locked) return;
                          setState(
                            () => _controlsVisible = !_controlsVisible,
                          );
                        },
                        onDoubleTapDown: (details) {
                          if (_locked) return;
                          if (details.localPosition.dx < box.maxWidth / 2) {
                            _seekBy(-10);
                          } else {
                            _seekBy(10);
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio == 0
                                    ? 16 / 9
                                    : controller.value.aspectRatio,
                                child: VideoPlayer(controller),
                              ),
                            ),
                            if (_controlsVisible || _locked)
                              _controls(controller),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 14),
            const Text(
              'تعذر تشغيل هذا الفيديو',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'قد يكون الترميز غير مدعوم في هذه النسخة الأولى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds.clamp(
          0,
          durationMs > 0 ? durationMs : 1,
        );
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
                      Colors.black.withOpacity(0.82),
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!_locked)
                    PopupMenuButton<double>(
                      tooltip: 'سرعة التشغيل',
                      iconColor: Colors.white,
                      initialValue: _speed,
                      onSelected: _changeSpeed,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0.5, child: Text('0.5×')),
                        PopupMenuItem(value: 0.75, child: Text('0.75×')),
                        PopupMenuItem(value: 1.0, child: Text('1×')),
                        PopupMenuItem(value: 1.25, child: Text('1.25×')),
                        PopupMenuItem(value: 1.5, child: Text('1.5×')),
                        PopupMenuItem(value: 2.0, child: Text('2×')),
                      ],
                    ),
                ],
              ),
            ),
            Center(
              child: _locked
                  ? FilledButton.tonalIcon(
                      onPressed: () => setState(() => _locked = false),
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('فتح التحكم'),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _seekBy(-10),
                          iconSize: 30,
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: 18),
                        IconButton.filled(
                          onPressed: () {
                            value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          },
                          iconSize: 44,
                          padding: const EdgeInsets.all(18),
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: 18),
                        IconButton.filledTonal(
                          onPressed: () => _seekBy(10),
                          iconSize: 30,
                          icon: const Icon(Icons.forward_10_rounded),
                        ),
                      ],
                    ),
            ),
            if (!_locked)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        min: 0,
                        max: durationMs > 0 ? durationMs.toDouble() : 1,
                        value: positionMs.toDouble(),
                        onChanged: durationMs > 0
                            ? (number) => controller.seekTo(
                                  Duration(milliseconds: number.round()),
                                )
                            : null,
                      ),
                      Row(
                        children: [
                          Text(
                            _time(value.position),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            _speed.toStringAsFixed(
                                  _speed == _speed.roundToDouble() ? 0 : 2,
                                ) +
                                '×',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => setState(() => _locked = true),
                            color: Colors.white,
                            icon: const Icon(Icons.lock_outline_rounded),
                          ),
                          const Spacer(),
                          Text(
                            _time(value.duration),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const Text(
                        'نقر مزدوج يمين/يسار للتقديم أو الترجيع 10 ثوانٍ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
