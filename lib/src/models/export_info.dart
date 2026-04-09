/// Represents an export directive
class ExportInfo {
  /// The file containing this export
  final String sourceFile;

  /// Resolved absolute path to exported file (null if external package)
  final String? resolvedPath;

  /// Original URI string
  final String uri;

  /// Show combinator names
  final List<String> showNames;

  /// Hide combinator names
  final List<String> hideNames;

  const ExportInfo({
    required this.sourceFile,
    required this.resolvedPath,
    required this.uri,
    this.showNames = const [],
    this.hideNames = const [],
  });

  /// Whether this export is from the same package
  bool get isInternalExport => resolvedPath != null;

  /// Compute which names are actually re-exported
  Set<String> getExportedNames(Set<String> availableNames) {
    if (showNames.isNotEmpty) {
      return availableNames.intersection(showNames.toSet());
    }
    return availableNames.difference(hideNames.toSet());
  }

  @override
  String toString() => 'ExportInfo($uri)';
}
