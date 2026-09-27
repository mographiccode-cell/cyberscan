import 'dart:io';

import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../services/media_library_service.dart';
import '../services/preferences_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/video_thumbnail.dart';
import 'player_page.dart';
import 'settings_page.dart';
import 'vault_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _library = MediaLibraryService();
  final _prefs = PreferencesService();

  bool _loading = true;
  List<VideoItem> _videos = const [];
  String _query = '';
  Set<String> _favorites = <String>{};
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final videos = await _library.loadVideos();
    final favorites = await _prefs.favorites();
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _favorites = favorites;
      _loading = false;
    });
  }

  List<VideoItem> get _filtered {
    Iterable<VideoItem> result = _videos;
    if (_tab == 1) {
      result = result.where((e) => _favorites.contains(e.id));
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result.where(
        (e) => e.title.toLowerCase().contains(q) || e.folder.toLowerCase().contains(q),
      );
    }
    return result.toList();
  }

  Future<void> _openItem(VideoItem item) async {
    final file = await _library.resolveFile(item);
    if (!mounted) return;
    if (file == null || !await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الوصول إلى ملف الفيديو.')),
      );
      return;
    }
    await _prefs.markRecent(item.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: PlayerPage(file: file, title: item.title),
        ),
      ),
    );
  }

  Future<void> _openPickedFile() async {
    final file = await _library.pickSingleVideo();
    if (file == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: PlayerPage(file: file, title: file.uri.pathSegments.last),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(VideoItem item) async {
    await _prefs.toggleFavorite(item.id);
    final favorites = await _prefs.favorites();
    if (mounted) setState(() => _favorites = favorites);
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أمان بلاير'),
            Text('تشغيل محلي • بدون حساب', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الخزنة الخاصة',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const Directionality(
                  textDirection: TextDirection.rtl,
                  child: VaultPage(),
                ),
              ),
            ),
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const Directionality(
                  textDirection: TextDirection.rtl,
                  child: SettingsPage(),
                ),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                hintText: 'ابحث في الفيديوهات والمجلدات',
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Segment(
                    label: 'الكل',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _Segment(
                    label: 'المفضلة',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'تحديث المكتبة',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : videos.isEmpty
                      ? EmptyState(
                          icon: _tab == 1 ? Icons.favorite_border : Icons.video_library_outlined,
                          title: _tab == 1 ? 'لا توجد مفضلة بعد' : 'لم نجد فيديوهات',
                          message: _tab == 1
                              ? 'اضغط على رمز القلب بجانب أي فيديو لإضافته.'
                              : 'امنح إذن الوصول للفيديوهات أو افتح ملفًا مباشرة.',
                        )
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                            itemCount: videos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final item = videos[index];
                              return _VideoRow(
                                item: item,
                                favorite: _favorites.contains(item.id),
                                onOpen: () => _openItem(item),
                                onFavorite: () => _toggleFavorite(item),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPickedFile,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('فتح فيديو'),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'تصميم وبرمجة م.محمود دغَبس • 74813824',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.item,
    required this.favorite,
    required this.onOpen,
    required this.onFavorite,
  });

  final VideoItem item;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  VideoThumbnail(asset: item.asset),
                  Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _duration(item.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                onPressed: onFavorite,
                icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
