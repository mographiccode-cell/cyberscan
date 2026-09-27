import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/video_item.dart';

class MediaLibraryService {
  Future<PermissionState> requestPermission() {
    return PhotoManager.requestPermissionExtend();
  }

  Future<List<VideoItem>> loadVideos({int limit = 1200}) async {
    final permission = await requestPermission();
    if (!permission.isAuth && !permission.hasAccess) return [];

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    final items = <VideoItem>[];
    for (final path in paths) {
      if (items.length >= limit) break;
      final count = await path.assetCountAsync;
      if (count == 0) continue;
      final assets = await path.getAssetListPaged(
        page: 0,
        size: (limit - items.length).clamp(1, 1000).toInt(),
      );
      for (final asset in assets) {
        final title = (asset.title ?? '').trim().isEmpty
            ? 'فيديو بدون اسم'
            : asset.title!.trim();
        items.add(VideoItem(asset: asset, title: title, folder: path.name));
        if (items.length >= limit) break;
      }
    }

    final unique = <String, VideoItem>{};
    for (final item in items) {
      unique[item.id] = item;
    }
    final result = unique.values.toList();
    result.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return result;
  }

  Future<File?> resolveFile(VideoItem item) async {
    final origin = await item.asset.originFile;
    return origin ?? await item.asset.file;
  }

  Future<File?> pickSingleVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return null;
    return File(path);
  }
}
