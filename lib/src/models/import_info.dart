/// Represents an import directive with all its metadata
class ImportInfo {
  /// The file containing this import
  final String sourceFile;

  /// Resolved absolute path to imported file (null if external package)
  final String? resolvedPath;

  /// Original URI string (e.g., 'package:foo/foo.dart')
  final String uri;

  /// Import prefix (e.g., 'foo' from 'as foo')
  final String? prefix;

  /// Show combinator names (only these are imported)
  final List<String> showNames;

  /// Hide combinator names (these are excluded)
  final List<String> hideNames;

  /// Whether this is a deferred import
  final bool isDeferred;

  const ImportInfo({
    required this.sourceFile,
    required this.resolvedPath,
    required this.uri,
    this.prefix,
    this.showNames = const [],
    this.hideNames = const [],
    this.isDeferred = false,
  });

  /// Whether this import is from the same package
  bool get isInternalImport => resolvedPath != null;

  /// Compute which names are actually imported given the combinators
  Set<String> getImportedNames(Set<String> availableNames) {
    if (showNames.isNotEmpty) {
      return availableNames.intersection(showNames.toSet());
    }
    return availableNames.difference(hideNames.toSet());
  }

  @override
  String toString() => 'ImportInfo($uri${prefix != null ? ' as $prefix' : ''})';
}
