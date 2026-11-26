import 'package:smartcard_flutter/core/services/api_config.dart';

class UploadUrlResolver {
  static const String _sharedUploadsDir = 'shared-uploads';
  static const Set<String> _sharedTopLevelDirs = {
    'users',
    'support',
    'messages',
    'card-bg',
    'templates',
    'agent-processes',
  };

  static String _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  static String get cacheBuster => _cacheBuster;

  static void bustCache() {
    _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String resolve(
    String? value, {
    required String type,
    String? fallback = '',
  }) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null' || raw.toLowerCase() == 'undefined') return fallback ?? '';
    if (raw.startsWith('data:')) return raw;
    if (raw.startsWith('/') || raw.startsWith('file://')) return raw;

    String resolved;
    final absolute = Uri.tryParse(raw);
    if (absolute != null && absolute.hasScheme) {
      if (absolute.scheme == 'http' || absolute.scheme == 'https') {
        final normalized = _normalizePath(absolute.path);
        if (normalized.isEmpty) {
          resolved = raw;
        } else if (_isSharedUploadsPath(normalized)) {
          resolved = _buildSharedUploadsUrl(normalized);
        } else if (normalized.startsWith('uploads/')) {
          resolved = '${_trimTrailing(ApiConfig.publicWebBaseUrl)}/$normalized';
        } else {
          resolved = raw;
        }
      } else if (absolute.scheme == 'file') {
        resolved = raw;
      } else {
        resolved = raw;
      }
    } else {
      final normalized = _normalizePath(raw);
      if (normalized.isEmpty) {
        resolved = fallback ?? '';
      } else if (_isSharedUploadsPath(normalized)) {
        resolved = _buildSharedUploadsUrl(normalized);
      } else if (normalized.startsWith('uploads/')) {
        resolved = '${_trimTrailing(ApiConfig.publicWebBaseUrl)}/$normalized';
      } else if (normalized.contains('/')) {
        resolved = _buildSharedUploadsUrl(normalized);
      } else if (type == 'logo') {
        resolved = _buildSharedUploadsUrl(
          '$_sharedUploadsDir/users/logo/$normalized',
        );
      } else if (type == 'card-bg' || type == 'background' || type == 'bg') {
        resolved = _buildSharedUploadsUrl(
          '$_sharedUploadsDir/card-bg/$normalized',
        );
      } else if (type == 'template') {
        resolved = _buildSharedUploadsUrl(
          '$_sharedUploadsDir/templates/$normalized',
        );
      } else if (type == 'gallery') {
        resolved = _buildSharedUploadsUrl(
          '$_sharedUploadsDir/users/gallery/$normalized',
        );
      } else {
        resolved = _buildSharedUploadsUrl(
          '$_sharedUploadsDir/users/profile/$normalized',
        );
      }
    }

    return resolved;
  }

  static String _normalizePath(String value) {
    final normalized = value.replaceAll('\\', '/').trim();
    final sharedIndex = normalized.indexOf('$_sharedUploadsDir/');
    if (sharedIndex >= 0) {
      return normalized.substring(sharedIndex).replaceFirst(RegExp(r'^/+'), '');
    }
    final uploadsIndex = normalized.indexOf('uploads/');
    if (uploadsIndex >= 0) {
      return normalized
          .substring(uploadsIndex)
          .replaceFirst(RegExp(r'^/+'), '');
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  static bool _isSharedUploadsPath(String value) {
    final normalized = value.replaceFirst(RegExp(r'^/+'), '').toLowerCase();
    if (normalized.startsWith('$_sharedUploadsDir/')) return true;
    final firstSegment = normalized.split('/').first;
    return _sharedTopLevelDirs.contains(firstSegment);
  }

  static String _buildSharedUploadsUrl(String value) {
    var normalized = value.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.toLowerCase().startsWith('$_sharedUploadsDir/')) {
      normalized = normalized.substring(_sharedUploadsDir.length + 1);
    }
    return '${_trimTrailing(ApiConfig.sharedUploadsUrl)}/$normalized';
  }

  static String _trimTrailing(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');
}
