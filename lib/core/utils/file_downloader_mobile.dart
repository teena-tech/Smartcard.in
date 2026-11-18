import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const MethodChannel _nativeChannel = MethodChannel('com.smartcard/native_contacts_helper');

Future<String?> saveFileToDevice(String fileName, Uint8List bytes) async {
  if (kIsWeb) return null;
  File? savedFile;

  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    } catch (_) {}

    // 1. Primary: Standard public Android Download directory (/storage/emulated/0/Download)
    final candidateDirs = <Directory>[
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Download'),
    ];

    try {
      final extDownloads = await getDownloadsDirectory();
      if (extDownloads != null) candidateDirs.insert(0, extDownloads);
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        if (await dir.exists()) {
          String finalName = fileName;
          File testFile = File('${dir.path}/$finalName');
          int counter = 1;
          final dotIdx = fileName.lastIndexOf('.');
          final baseName = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
          final ext = dotIdx != -1 ? fileName.substring(dotIdx) : '';
          while (await testFile.exists()) {
            finalName = '${baseName}_$counter$ext';
            testFile = File('${dir.path}/$finalName');
            counter++;
          }
          await testFile.writeAsBytes(bytes, flush: true);
          savedFile = testFile;
          break;
        }
      } catch (_) {
        // Continue to next candidate
      }
    }

    // 2. Fallback to external storage directory
    if (savedFile == null) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);
          savedFile = file;
        }
      } catch (_) {}
    }
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedFile = file;
    } catch (_) {}
  } else {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        savedFile = file;
      }
    } catch (_) {}
  }

  // 3. Ultimate fallback
  if (savedFile == null) {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedFile = file;
    } catch (_) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedFile = file;
    }
  }

  if (savedFile != null && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final isSvg = fileName.toLowerCase().endsWith('.svg');
      final mime = isSvg ? 'image/svg+xml' : 'image/png';
      await _nativeChannel.invokeMethod('notifyDownloadComplete', {
        'filePath': savedFile.path,
        'fileName': fileName,
        'mimeType': mime,
      });
    } catch (_) {}
  }

  return savedFile?.path;
}
