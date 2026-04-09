import 'dart:io';

import 'package:knipdart/src/cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = buildCommandRunner();

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
