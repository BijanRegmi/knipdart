import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/analysis_result.dart';
import '../models/declaration.dart';

/// Reports analysis results to console
class ConsoleReporter {
  final bool verbose;
  final String? projectRoot;

  ConsoleReporter({
    this.verbose = false,
    this.projectRoot,
  });

  void report(AnalysisResult result) {
    final stats = result.stats;

    if (result.unusedExports.isEmpty) {
      stdout.writeln('No unused exports found.');
      _printStats(stats);
      return;
    }

    // Group by file
    final byFile = <String, List<UnusedExport>>{};
    for (final export in result.unusedExports) {
      byFile
          .putIfAbsent(export.declaration.filePath, () => [])
          .add(export);
    }

    // Print completely unused
    final completelyUnused = result.completelyUnused;
    if (completelyUnused.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('Unused exports (${completelyUnused.length}):');
      stdout.writeln('');
      _printExports(completelyUnused, byFile);
    }

    // Print used only in tests
    final testOnly = result.usedOnlyInTests;
    if (testOnly.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('Used only in tests (${testOnly.length}):');
      stdout.writeln('');
      _printExports(testOnly, byFile);
    }

    stdout.writeln('');
    _printStats(stats);
  }

  void _printExports(
    List<UnusedExport> exports,
    Map<String, List<UnusedExport>> byFile,
  ) {
    // Group the specific exports by file
    final groupedByFile = <String, List<UnusedExport>>{};
    for (final export in exports) {
      groupedByFile
          .putIfAbsent(export.declaration.filePath, () => [])
          .add(export);
    }

    for (final entry in groupedByFile.entries) {
      final filePath = _relativePath(entry.key);
      final fileExports = entry.value;

      stdout.writeln(filePath);

      for (var i = 0; i < fileExports.length; i++) {
        final export = fileExports[i];
        final isLast = i == fileExports.length - 1;
        final prefix = isLast ? '  \u2514\u2500\u2500 ' : '  \u251c\u2500\u2500 ';

        final typeStr = _typeToString(export.declaration.type);
        stdout.writeln(
          '$prefix${export.declaration.name} ($typeStr)',
        );

        if (verbose && export.exportedVia != null) {
          final viaPrefix = isLast ? '      ' : '  \u2502   ';
          stdout.writeln(
            '${viaPrefix}exported via: ${_relativePath(export.exportedVia!)}',
          );
        }
      }

      stdout.writeln('');
    }
  }

  void _printStats(AnalysisStats stats) {
    stdout.writeln('Summary:');
    stdout.writeln('  Total files: ${stats.totalFiles}');
    stdout.writeln('  Total declarations: ${stats.totalDeclarations}');
    stdout.writeln('  Public exports: ${stats.publicDeclarations}');
    stdout.writeln('  Unused exports: ${stats.unusedExports}');
    if (stats.usedOnlyInTests > 0) {
      stdout.writeln('  Used only in tests: ${stats.usedOnlyInTests}');
    }
    stdout.writeln('');
    stdout.writeln(
      'Analysis completed in ${stats.analysisTime.inMilliseconds}ms',
    );
  }

  String _relativePath(String path) {
    if (projectRoot != null) {
      return p.relative(path, from: projectRoot);
    }
    return path;
  }

  String _typeToString(DeclarationType type) {
    return switch (type) {
      DeclarationType.classDeclaration => 'class',
      DeclarationType.functionDeclaration => 'function',
      DeclarationType.topLevelVariable => 'variable',
      DeclarationType.typedef => 'typedef',
      DeclarationType.enumDeclaration => 'enum',
      DeclarationType.extension => 'extension',
      DeclarationType.extensionType => 'extension type',
      DeclarationType.mixin => 'mixin',
    };
  }
}
