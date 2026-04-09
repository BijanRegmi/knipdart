import 'declaration.dart';

/// Category of unused export
enum UnusedCategory {
  /// Not used anywhere
  unused,

  /// Only used in test files
  usedOnlyInTests,
}

/// Represents an unused export
class UnusedExport {
  /// The declaration that is unused
  final Declaration declaration;

  /// How it's exported (the public API file path, if via barrel)
  final String? exportedVia;

  /// Category of unused
  final UnusedCategory category;

  const UnusedExport({
    required this.declaration,
    this.exportedVia,
    required this.category,
  });

  @override
  String toString() =>
      'UnusedExport(${declaration.name}, ${category.name}, ${declaration.filePath})';
}

/// Statistics about the analysis
class AnalysisStats {
  final int totalFiles;
  final int totalDeclarations;
  final int publicDeclarations;
  final int unusedExports;
  final int usedOnlyInTests;
  final Duration analysisTime;

  const AnalysisStats({
    required this.totalFiles,
    required this.totalDeclarations,
    required this.publicDeclarations,
    required this.unusedExports,
    required this.usedOnlyInTests,
    required this.analysisTime,
  });
}

/// Warning during analysis
class AnalysisWarning {
  final String message;
  final String? filePath;

  const AnalysisWarning(this.message, [this.filePath]);

  @override
  String toString() =>
      filePath != null ? '$filePath: $message' : message;
}

/// Final result of the analysis
class AnalysisResult {
  /// All unused exports found
  final List<UnusedExport> unusedExports;

  /// Statistics about the analysis
  final AnalysisStats stats;

  /// Any warnings during analysis
  final List<AnalysisWarning> warnings;

  const AnalysisResult({
    required this.unusedExports,
    required this.stats,
    this.warnings = const [],
  });

  /// Exports that are completely unused
  List<UnusedExport> get completelyUnused =>
      unusedExports.where((e) => e.category == UnusedCategory.unused).toList();

  /// Exports used only in tests
  List<UnusedExport> get usedOnlyInTests => unusedExports
      .where((e) => e.category == UnusedCategory.usedOnlyInTests)
      .toList();
}
