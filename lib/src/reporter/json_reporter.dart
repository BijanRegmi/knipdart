import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/analysis_result.dart';
import '../models/declaration.dart';

/// Reports analysis results as JSON
class JsonReporter {
  final String? projectRoot;

  JsonReporter({this.projectRoot});

  void report(
    AnalysisResult result, {
    bool showUnused = true,
    bool showLocal = true,
    bool showTest = true,
  }) {
    final output = <String, dynamic>{
      if (showUnused)
        'unusedExports': result.completelyUnused.map(_exportToJson).toList(),
      if (showLocal)
        'usedOnlyLocally': result.usedOnlyLocally.map(_exportToJson).toList(),
      if (showTest)
        'usedOnlyInTests': result.usedOnlyInTests.map(_exportToJson).toList(),
      'stats': {
        'totalFiles': result.stats.totalFiles,
        'totalDeclarations': result.stats.totalDeclarations,
        'publicExports': result.stats.publicDeclarations,
        if (showUnused) 'unusedExports': result.stats.unusedExports,
        if (showLocal) 'usedOnlyLocally': result.stats.usedOnlyLocally,
        if (showTest) 'usedOnlyInTests': result.stats.usedOnlyInTests,
        'analysisTimeMs': result.stats.analysisTime.inMilliseconds,
      },
      'warnings': result.warnings.map((w) => w.toString()).toList(),
    };

    stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
  }

  Map<String, dynamic> _exportToJson(UnusedExport export) {
    return {
      'file': _relativePath(export.declaration.filePath),
      'name': export.declaration.name,
      'type': _typeToString(export.declaration.type),
      'line': export.declaration.lineNumber,
      if (export.exportedVia != null)
        'exportedVia': _relativePath(export.exportedVia!),
    };
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
      DeclarationType.extensionType => 'extensionType',
      DeclarationType.mixin => 'mixin',
    };
  }
}
