import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/analysis_result.dart';
import '../models/declaration.dart';

/// Reports analysis results as JSON
class JsonReporter {
  final String? projectRoot;

  JsonReporter({this.projectRoot});

  void report(AnalysisResult result) {
    final output = {
      'unusedExports': result.completelyUnused.map(_exportToJson).toList(),
      'usedOnlyInTests': result.usedOnlyInTests.map(_exportToJson).toList(),
      'stats': {
        'totalFiles': result.stats.totalFiles,
        'totalDeclarations': result.stats.totalDeclarations,
        'publicExports': result.stats.publicDeclarations,
        'unusedExports': result.stats.unusedExports,
        'usedOnlyInTests': result.stats.usedOnlyInTests,
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
