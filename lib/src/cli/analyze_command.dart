import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../analyzer/project_analyzer.dart';
import '../models/declaration.dart';
import '../reporter/json_reporter.dart';
import 'progress.dart';

/// The main analyze command
class AnalyzeCommand extends Command<int> {
  @override
  final String name = 'analyze';

  @override
  final String description = 'Analyze a Dart project for unused exports';

  AnalyzeCommand() {
    argParser
      ..addOption(
        'format',
        abbr: 'f',
        allowed: ['console', 'json'],
        defaultsTo: 'console',
        help: 'Output format',
      )
      ..addMultiOption(
        'exclude',
        abbr: 'e',
        help: 'Glob patterns to exclude from analysis',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'Show detailed analysis information',
      )
      ..addFlag(
        'no-color',
        defaultsTo: false,
        help: 'Disable colored output',
      )
      ..addFlag(
        'no-spinner',
        defaultsTo: false,
        help: 'Disable spinner animation',
      );
  }

  @override
  Future<int> run() async {
    final path = argResults!.rest.isEmpty
        ? Directory.current.path
        : argResults!.rest.first;

    final absolutePath = p.isAbsolute(path) ? path : p.absolute(path);

    if (!Directory(absolutePath).existsSync()) {
      stderr.writeln('Error: Directory not found: $absolutePath');
      return 1;
    }

    final pubspecPath = p.join(absolutePath, 'pubspec.yaml');
    if (!File(pubspecPath).existsSync()) {
      stderr.writeln('Error: No pubspec.yaml found in $absolutePath');
      return 1;
    }

    final format = argResults!['format'] as String;
    final exclude = argResults!['exclude'] as List<String>;
    final noColor = argResults!['no-color'] as bool;
    final noSpinner = argResults!['no-spinner'] as bool;

    // Use JSON format silently
    if (format == 'json') {
      return _runJsonAnalysis(absolutePath, exclude);
    }

    // Use fancy console output
    return _runConsoleAnalysis(
      absolutePath,
      exclude,
      useColors: !noColor,
      useSpinner: !noSpinner,
    );
  }

  Future<int> _runJsonAnalysis(String absolutePath, List<String> exclude) async {
    try {
      final analyzer = ProjectAnalyzer(
        projectPath: absolutePath,
        excludePatterns: exclude,
      );

      final result = await analyzer.analyze();
      JsonReporter(projectRoot: absolutePath).report(result);

      return result.completelyUnused.isEmpty ? 0 : 1;
    } catch (e) {
      stderr.writeln('{"error": "${e.toString().replaceAll('"', '\\"')}"}');
      return 1;
    }
  }

  Future<int> _runConsoleAnalysis(
    String absolutePath,
    List<String> exclude, {
    required bool useColors,
    required bool useSpinner,
  }) async {
    final progress = ProgressReporter(
      useColors: useColors,
      useSpinner: useSpinner,
    );

    final relativePath = p.relative(absolutePath, from: Directory.current.path);
    final displayPath = relativePath.isEmpty || relativePath == '.'
        ? p.basename(absolutePath)
        : relativePath;

    progress.start(displayPath);

    AnalysisPhase? currentPhase;

    try {
      final analyzer = ProjectAnalyzer(
        projectPath: absolutePath,
        excludePatterns: exclude,
        onProgress: (progressInfo) {
          if (progressInfo.phase != currentPhase) {
            // Complete previous phase
            if (currentPhase != null && currentPhase != AnalysisPhase.complete) {
              progress.completePhase();
            }

            currentPhase = progressInfo.phase;

            // Start new phase
            if (progressInfo.phase != AnalysisPhase.complete) {
              final progressPhase = switch (progressInfo.phase) {
                AnalysisPhase.discovery => ProgressPhase.discovery,
                AnalysisPhase.parsing => ProgressPhase.parsing,
                AnalysisPhase.exportGraph => ProgressPhase.exportGraph,
                AnalysisPhase.usageGraph => ProgressPhase.usageGraph,
                AnalysisPhase.findingUnused => ProgressPhase.analysis,
                AnalysisPhase.complete => ProgressPhase.analysis,
              };
              progress.startPhase(
                progressPhase,
                totalFiles: progressInfo.totalFiles,
              );
            }
          } else if (progressInfo.currentFile != null) {
            progress.updateFileProgress(
              progressInfo.currentFile!,
              total: progressInfo.totalFiles,
            );
          }
        },
      );

      final result = await analyzer.analyze();

      // Complete the last phase
      progress.completePhase();

      // Show warnings
      for (final warning in result.warnings) {
        progress.warning(warning.toString());
      }

      // Show results
      progress.showResults(
        totalFiles: result.stats.totalFiles,
        totalDeclarations: result.stats.totalDeclarations,
        publicExports: result.stats.publicDeclarations,
        unusedExports: result.stats.unusedExports,
        usedOnlyInTests: result.stats.usedOnlyInTests,
        unused: result.completelyUnused
            .map((e) => UnusedExportInfo(
                  filePath: p.relative(e.declaration.filePath, from: absolutePath),
                  name: e.declaration.name,
                  type: _typeToString(e.declaration.type),
                ),)
            .toList(),
        testOnly: result.usedOnlyInTests
            .map((e) => UnusedExportInfo(
                  filePath: p.relative(e.declaration.filePath, from: absolutePath),
                  name: e.declaration.name,
                  type: _typeToString(e.declaration.type),
                ),)
            .toList(),
      );

      stdout.writeln();

      return result.completelyUnused.isEmpty ? 0 : 1;
    } catch (e, stackTrace) {
      progress.completePhase(success: false);
      stderr.writeln();
      stderr.writeln('Error: $e');
      if (argResults!['verbose'] as bool) {
        stderr.writeln(stackTrace);
      }
      return 1;
    }
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
