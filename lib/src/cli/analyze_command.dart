import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../analyzer/project_analyzer.dart';
import '../reporter/console_reporter.dart';
import '../reporter/json_reporter.dart';

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
    final verbose = argResults!['verbose'] as bool;

    try {
      final analyzer = ProjectAnalyzer(
        projectPath: absolutePath,
        excludePatterns: exclude,
        verbose: verbose,
      );

      if (verbose) {
        stderr.writeln('Analyzing project: $absolutePath');
      }

      final result = await analyzer.analyze();

      // Print warnings
      for (final warning in result.warnings) {
        stderr.writeln('Warning: $warning');
      }

      // Report results
      switch (format) {
        case 'json':
          JsonReporter(projectRoot: absolutePath).report(result);
        case 'console':
        default:
          ConsoleReporter(
            verbose: verbose,
            projectRoot: absolutePath,
          ).report(result);
      }

      // Return non-zero if there are unused exports
      return result.completelyUnused.isEmpty ? 0 : 1;
    } catch (e, stackTrace) {
      stderr.writeln('Error: $e');
      if (verbose) {
        stderr.writeln(stackTrace);
      }
      return 1;
    }
  }
}
