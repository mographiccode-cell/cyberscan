import 'dart:io';

import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import '../widgets/empty_state.dart';
import 'player_page.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _service = VaultService();
  bool _loading = true;
  bool _unlocked = false;
  List<VaultItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    final ok = await _service.unlock();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _unlocked = false;
      });
      return;
    }
    final items = await _service.list();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _unlocked = true;
      _items = items;
    });
  }

  Future<void> _import() async {
    final item = await _service.importVideo();
    if (item == null) return;
    final items = await _service.list();
    if (mounted) {
      setState(() => _items = items);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ الفيديو إلى مساحة التطبيق الخاصة. احذف الأصل من المعرض إذا أردت أن تبقى النسخة الخاصة فقط.'),
        ),
      );
    }
  }

  String _size(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخزنة الخاصة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_unlocked
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('فتح الخزنة'),
                  ),
                )
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.shield_outlined,
                      title: 'الخزنة فارغة',
                      message: 'أضف فيديوهات إلى مساحة التطبيق الخاصة. فتح الخزنة محمي بقفل الجهاز عند توفره.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.lock_rounded)),
                            title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(_size(item.size)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: PlayerPage(file: File(item.path), title: item.name),
                                ),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value != 'delete') return;
                                await _service.delete(item);
                                final items = await _service.list();
                                if (mounted) setState(() => _items = items);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'delete', child: Text('حذف من الخزنة')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _unlocked
          ? FloatingActionButton.extended(
              onPressed: _import,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة فيديو'),
            )
          : null,
    );
  }
}
