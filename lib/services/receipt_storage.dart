import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiptStorage {
  static Future<Directory> _receiptsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<FileSystemEntity>> listReceipts() async {
    final dir = await _receiptsDir();
    final items = await dir.list().toList();
    items.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return items;
  }

  /// Import shared files into the app's receipts directory and return count imported.
  static Future<int> importSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return 0;
    final dir = await _receiptsDir();
    var imported = 0;
    for (final f in files) {
      try {
        final src = File(f.path);
        if (!await src.exists()) continue;
        final name = p.basename(f.path);
        var destPath = p.join(dir.path, name);
        // Avoid overwriting: if exists, append a counter
        if (await File(destPath).exists()) {
          final stem = p.basenameWithoutExtension(name);
          final ext = p.extension(name);
          var i = 1;
          while (await File(destPath).exists()) {
            destPath = p.join(dir.path, '${stem} (${i++})${ext}');
          }
        }
        await src.copy(destPath);
        imported++;
      } catch (_) {
        // skip on error
      }
    }
    return imported;
  }
}

