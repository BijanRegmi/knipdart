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
      )
      ..addOption(
        'project-root',
        abbr: 'p',
        help: 'Project root directory (where pubspec.yaml is located). '
            'If not specified, scans upward from the analyze path.',
      )
      ..addMultiOption(
        'show',
        abbr: 's',
        allowed: ['unused', 'local', 'test'],
        help: 'Filter which types of unused exports to show. '
            'Options: unused (completely unused), local (used only locally), '
            'test (used only in tests). Shows all if not specified.',
      );
  }

  @override
  Future<int> run() async {
    // The path argument is the scope to analyze (defaults to current directory)
    final scopePath = argResults!.rest.isEmpty
        ? Directory.current.path
        : argResults!.rest.first;

    final absoluteScopePath =
        p.isAbsolute(scopePath) ? scopePath : p.absolute(scopePath);

    if (!Directory(absoluteScopePath).existsSync() &&
        !File(absoluteScopePath).existsSync()) {
      stderr.writeln('Error: Path not found: $absoluteScopePath');
      return 1;
    }

    // Project root is where pubspec.yaml lives
    final projectRootArg = argResults!['project-root'] as String?;
    final String projectRoot;

    if (projectRootArg != null) {
      projectRoot = p.isAbsolute(projectRootArg)
          ? projectRootArg
          : p.absolute(projectRootArg);
    } else {
      // Scan upwards from scope path to find pubspec.yaml
      final foundRoot = _findProjectRoot(absoluteScopePath);
      if (foundRoot == null) {
        stderr.writeln(
            'Error: No pubspec.yaml found in $absoluteScopePath or any parent directory',);
        return 1;
      }
      projectRoot = foundRoot;
    }

    final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
    if (!File(pubspecPath).existsSync()) {
      stderr.writeln('Error: No pubspec.yaml found in $projectRoot');
      return 1;
    }

    // Validate scope path is within project root
    if (!p.isWithin(projectRoot, absoluteScopePath) &&
        absoluteScopePath != projectRoot) {
      stderr.writeln(
          'Error: Scope path must be within project root: $absoluteScopePath',);
      return 1;
    }

    final format = argResults!['format'] as String;
    final exclude = argResults!['exclude'] as List<String>;
    final noColor = argResults!['no-color'] as bool;
    final noSpinner = argResults!['no-spinner'] as bool;
    final showTypes = argResults!['show'] as List<String>;

    // If no types specified, show all
    final showUnused = showTypes.isEmpty || showTypes.contains('unused');
    final showLocal = showTypes.isEmpty || showTypes.contains('local');
    final showTest = showTypes.isEmpty || showTypes.contains('test');

    // Determine scope paths (relative to project root)
    final scopePaths = absoluteScopePath == projectRoot
        ? <String>[]
        : [absoluteScopePath];

    // Use JSON format silently
    if (format == 'json') {
      return _runJsonAnalysis(
        projectRoot,
        exclude,
        scopePaths,
        showUnused: showUnused,
        showLocal: showLocal,
        showTest: showTest,
      );
    }

    // Use fancy console output
    return _runConsoleAnalysis(
      projectRoot,
      exclude,
      scopePaths,
      useColors: !noColor,
      useSpinner: !noSpinner,
      showUnused: showUnused,
      showLocal: showLocal,
      showTest: showTest,
    );
  }

  Future<int> _runJsonAnalysis(
    String projectRoot,
    List<String> exclude,
    List<String> scopePaths, {
    required bool showUnused,
    required bool showLocal,
    required bool showTest,
  }) async {
    try {
      final analyzer = ProjectAnalyzer(
        projectPath: projectRoot,
        excludePatterns: exclude,
        scopePaths: scopePaths,
      );

      final result = await analyzer.analyze();
      JsonReporter(projectRoot: projectRoot).report(
        result,
        showUnused: showUnused,
        showLocal: showLocal,
        showTest: showTest,
      );

      return result.completelyUnused.isEmpty ? 0 : 1;
    } catch (e) {
      stderr.writeln('{"error": "${e.toString().replaceAll('"', '\\"')}"}');
      return 1;
    }
  }

  Future<int> _runConsoleAnalysis(
    String projectRoot,
    List<String> exclude,
    List<String> scopePaths, {
    required bool useColors,
    required bool useSpinner,
    required bool showUnused,
    required bool showLocal,
    required bool showTest,
  }) async {
    final progress = ProgressReporter(
      useColors: useColors,
      useSpinner: useSpinner,
    );

    // Display the scope path if specified, otherwise the project root
    final displayTarget =
        scopePaths.isNotEmpty ? scopePaths.first : projectRoot;
    final relativePath =
        p.relative(displayTarget, from: Directory.current.path);
    final displayPath = relativePath.isEmpty || relativePath == '.'
        ? p.basename(displayTarget)
        : relativePath;

    progress.start(displayPath);

    AnalysisPhase? currentPhase;

    try {
      final analyzer = ProjectAnalyzer(
        projectPath: projectRoot,
        excludePatterns: exclude,
        scopePaths: scopePaths,
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

      // Show results (filtered by --show flag)
      progress.showResults(
        totalFiles: result.stats.totalFiles,
        totalDeclarations: result.stats.totalDeclarations,
        publicExports: result.stats.publicDeclarations,
        unusedExports: showUnused ? result.stats.unusedExports : null,
        usedOnlyLocally: showLocal ? result.stats.usedOnlyLocally : null,
        usedOnlyInTests: showTest ? result.stats.usedOnlyInTests : null,
        unused: showUnused
            ? result.completelyUnused
                .map((e) => UnusedExportInfo(
                      filePath: p.relative(e.declaration.filePath, from: projectRoot),
                      name: e.declaration.name,
                      type: _typeToString(e.declaration.type),
                    ),)
                .toList()
            : [],
        localOnly: showLocal
            ? result.usedOnlyLocally
                .map((e) => UnusedExportInfo(
                      filePath: p.relative(e.declaration.filePath, from: projectRoot),
                      name: e.declaration.name,
                      type: _typeToString(e.declaration.type),
                    ),)
                .toList()
            : [],
        testOnly: showTest
            ? result.usedOnlyInTests
                .map((e) => UnusedExportInfo(
                      filePath: p.relative(e.declaration.filePath, from: projectRoot),
                      name: e.declaration.name,
                      type: _typeToString(e.declaration.type),
                    ),)
                .toList()
            : [],
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

  /// Scan upwards from the given path to find the project root (containing pubspec.yaml)
  String? _findProjectRoot(String startPath) {
    var current = Directory(startPath).existsSync()
        ? startPath
        : p.dirname(startPath);

    while (true) {
      final pubspecPath = p.join(current, 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) {
        return current;
      }

      final parent = p.dirname(current);
      if (parent == current) {
        // Reached filesystem root
        return null;
      }
      current = parent;
    }
  }
}
