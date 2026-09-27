import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

class VaultItem {
  const VaultItem({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String path;
  final int size;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'size': size,
        'addedAt': addedAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        size: (json['size'] as num).toInt(),
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}

class VaultService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}index.json');
  }

  Future<bool> unlock() async {
    final supported = await _auth.isDeviceSupported();
    if (!supported) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'افتح الخزنة الخاصة في أمان بلاير',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<List<VaultItem>> list() async {
    final index = await _indexFile();
    if (!await index.exists()) return [];
    try {
      final raw = jsonDecode(await index.readAsString()) as List<dynamic>;
      final values = raw
          .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => File(e.path).existsSync())
          .toList();
      values.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return values;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<VaultItem> items) async {
    final index = await _indexFile();
    await index.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<VaultItem?> importVideo() async {
    final selected = await FilePicker.pickFile(type: FileType.video);
    final sourcePath = selected?.path;
    if (sourcePath == null) return null;

    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final dir = await _directory();
    final now = DateTime.now();
    final originalName = selected!.name;
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._\-\u0600-\u06FF ]'), '_');
    final target = File(
      '${dir.path}${Platform.pathSeparator}${now.microsecondsSinceEpoch}_$safeName',
    );
    await source.copy(target.path);
    final item = VaultItem(
      id: now.microsecondsSinceEpoch.toString(),
      name: originalName,
      path: target.path,
      size: await target.length(),
      addedAt: now,
    );
    final items = await list();
    items.add(item);
    await _save(items);
    return item;
  }

  Future<void> delete(VaultItem item) async {
    final file = File(item.path);
    if (await file.exists()) await file.delete();
    final items = await list()..removeWhere((e) => e.id == item.id);
    await _save(items);
  }
}
