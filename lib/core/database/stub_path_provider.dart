// Web stub for path_provider.
// The real path_provider is not supported on web.
// This stub is only used when building for web (dart.library.html).
// The actual call site is guarded by `kIsWeb`, so this is never executed.

class Directory {
  final String path;
  const Directory(this.path);
}

Future<Directory> getApplicationDocumentsDirectory() async {
  // Never called on web — guarded by kIsWeb in HiveDatabase.init()
  return const Directory('');
}
