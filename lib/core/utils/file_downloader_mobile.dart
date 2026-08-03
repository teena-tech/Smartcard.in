import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> saveFileToDevice(String fileName, Uint8List bytes) async {
  if (kIsWeb) return;
  Directory? directory;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Attempt permission request for older Android versions
    try {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    } catch (_) {}

    // 1. Try public Download folder (/storage/emulated/0/Download)
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return;
      }
    } catch (_) {
      // Direct write failed due to Android 10+ scoped storage policies
    }

    // 2. Fallback to external storage directory
    try {
      directory = await getExternalStorageDirectory();
    } catch (_) {}
  } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    try {
      directory = await getDownloadsDirectory();
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }
  }

  // 3. Ultimate fallback
  directory ??= await getApplicationDocumentsDirectory();

  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
}
