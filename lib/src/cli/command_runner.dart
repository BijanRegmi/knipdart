import 'package:args/command_runner.dart';

import 'analyze_command.dart';

/// Creates and configures the command runner for knipdart
CommandRunner<int> buildCommandRunner() {
  final runner = CommandRunner<int>(
    'knipdart',
    'Find unused exports in Dart/Flutter projects',
  );

  runner.addCommand(AnalyzeCommand());

  return runner;
}
