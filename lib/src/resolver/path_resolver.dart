import 'package:path/path.dart' as p;

/// Resolves import/export URIs to absolute file paths
class PathResolver {
  /// Package name from pubspec.yaml
  final String packageName;

  /// Absolute path to project root
  final String projectRoot;

  /// Path to lib directory
  late final String libPath = p.join(projectRoot, 'lib');

  PathResolver({
    required this.packageName,
    required this.projectRoot,
  });

  /// Resolve a URI to an absolute path
  ///
  /// Returns null if the URI points to an external package or dart: library
  String? resolve(String uri, {required String fromFile}) {
    // dart: URIs are external
    if (uri.startsWith('dart:')) {
      return null;
    }

    // package: URIs
    if (uri.startsWith('package:')) {
      return _resolvePackageUri(uri);
    }

    // Relative URIs
    return _resolveRelativeUri(uri, fromFile);
  }

  /// Resolve a package: URI
  String? _resolvePackageUri(String uri) {
    // package:foo/bar.dart -> lib/bar.dart if foo is our package
    final match = RegExp(r'^package:([^/]+)/(.+)$').firstMatch(uri);
    if (match == null) return null;

    final packagePart = match.group(1)!;
    final pathPart = match.group(2)!;

    // Only resolve our own package
    if (packagePart != packageName) {
      return null;
    }

    return p.normalize(p.join(libPath, pathPart));
  }

  /// Resolve a relative URI
  String? _resolveRelativeUri(String uri, String fromFile) {
    final fromDir = p.dirname(fromFile);
    return p.normalize(p.join(fromDir, uri));
  }

  /// Check if a path is within the project's lib directory
  bool isInLib(String path) {
    return p.isWithin(libPath, path);
  }

  /// Check if a path is within lib/src/
  bool isInLibSrc(String path) {
    final srcPath = p.join(libPath, 'src');
    return p.isWithin(srcPath, path);
  }

  /// Check if a path is a test file
  bool isTestFile(String path) {
    final testPath = p.join(projectRoot, 'test');
    return p.isWithin(testPath, path);
  }

  /// Get the relative path from project root
  String relativePath(String absolutePath) {
    return p.relative(absolutePath, from: projectRoot);
  }
}
