import 'dart:async';
import 'dart:io';

/// ANSI color codes
class Colors {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';

  // Foreground colors
  static const black = '\x1B[30m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';

  // Bright foreground colors
  static const brightRed = '\x1B[91m';
  static const brightGreen = '\x1B[92m';
  static const brightYellow = '\x1B[93m';
  static const brightBlue = '\x1B[94m';
  static const brightMagenta = '\x1B[95m';
  static const brightCyan = '\x1B[96m';
  static const brightWhite = '\x1B[97m';

  // Background colors
  static const bgBlue = '\x1B[44m';
  static const bgGreen = '\x1B[42m';
  static const bgRed = '\x1B[41m';
  static const bgYellow = '\x1B[43m';
}

/// Unicode symbols
class Symbols {
  static const checkMark = '✓';
  static const cross = '✗';
  static const bullet = '●';
  static const arrow = '→';
  static const arrowRight = '❯';
  static const warning = '⚠';
  static const info = 'ℹ';
  static const folder = '📁';
  static const file = '📄';
  static const search = '🔍';
  static const lightning = '⚡';
  static const sparkles = '✨';

  // Box drawing
  static const boxTopLeft = '╭';
  static const boxTopRight = '╮';
  static const boxBottomLeft = '╰';
  static const boxBottomRight = '╯';
  static const boxHorizontal = '─';
  static const boxVertical = '│';

  // Spinner frames
  static const spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  static const dotsFrames = ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'];
  static const arrowFrames = ['←', '↖', '↑', '↗', '→', '↘', '↓', '↙'];
}

/// Progress phase
enum ProgressPhase {
  discovery,
  parsing,
  exportGraph,
  usageGraph,
  analysis,
}

/// ANSI cursor control
class Cursor {
  static const hide = '\x1B[?25l';
  static const show = '\x1B[?25h';
  static const moveToStart = '\r';
  static const clearLine = '\x1B[K';
  static const clearToEnd = '\x1B[0K';
  static const saveCursor = '\x1B[s';
  static const restoreCursor = '\x1B[u';
}

/// Progress reporter with spinners and colors
class ProgressReporter {
  final bool useColors;
  final bool useSpinner;

  Timer? _spinnerTimer;
  int _spinnerFrame = 0;
  String _currentMessage = '';
  ProgressPhase? _currentPhase;
  final Stopwatch _phaseStopwatch = Stopwatch();
  final Stopwatch _totalStopwatch = Stopwatch();
  final Map<ProgressPhase, Duration> _phaseDurations = {};

  int _fileCount = 0;
  int _currentFile = 0;

  ProgressReporter({
    this.useColors = true,
    this.useSpinner = true,
  });

  String _color(String text, String color) {
    if (!useColors) return text;
    return '$color$text${Colors.reset}';
  }

  String _bold(String text) {
    if (!useColors) return text;
    return '${Colors.bold}$text${Colors.reset}';
  }

  String _dim(String text) {
    if (!useColors) return text;
    return '${Colors.dim}$text${Colors.reset}';
  }

  void _startSpinner(String message) {
    _currentMessage = message;
    _spinnerFrame = 0;
    _lastOutput = '';

    if (!useSpinner) {
      stdout.writeln('  ... $message');
      return;
    }

    // Hide cursor for smooth animation
    stdout.write(Cursor.hide);

    _spinnerTimer?.cancel();
    _spinnerTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _updateSpinner(),
    );
    _updateSpinner();
  }

  void _updateSpinner() {
    final frame = Symbols.spinnerFrames[_spinnerFrame % Symbols.spinnerFrames.length];
    final spinner = _color(frame, Colors.cyan);

    String progress = '';
    if (_fileCount > 0 && _currentFile > 0) {
      final percent = ((_currentFile / _fileCount) * 100).toStringAsFixed(0).padLeft(3);
      final current = _currentFile.toString().padLeft(_fileCount.toString().length);
      progress = _dim(' [$current/$_fileCount] $percent%');
    }

    // Build the full line with fixed width to prevent jumping
    final content = '  $spinner $_currentMessage$progress';

    // Move to start of line, clear to end, write content
    stdout.write('\r\x1B[K$content');

    _spinnerFrame++;
  }

  void _stopSpinner({bool success = true}) {
    _spinnerTimer?.cancel();
    _spinnerTimer = null;

    // Clear line and show cursor
    stdout.write('\r\x1B[K');
    stdout.write(Cursor.show);

    final icon = success
        ? _color(Symbols.checkMark, Colors.green)
        : _color(Symbols.cross, Colors.red);

    final elapsed = _phaseStopwatch.elapsed;
    final time = _dim('(${_formatDuration(elapsed)})');

    stdout.writeln('  $icon $_currentMessage $time');
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
  }

  String _getPhaseMessage(ProgressPhase phase) {
    return switch (phase) {
      ProgressPhase.discovery => 'Discovering project structure',
      ProgressPhase.parsing => 'Parsing Dart files',
      ProgressPhase.exportGraph => 'Building export graph',
      ProgressPhase.usageGraph => 'Analyzing symbol usage',
      ProgressPhase.analysis => 'Finding unused exports',
    };
  }

  String _getPhaseIcon(ProgressPhase phase) {
    return switch (phase) {
      ProgressPhase.discovery => Symbols.folder,
      ProgressPhase.parsing => Symbols.file,
      ProgressPhase.exportGraph => '🔗',
      ProgressPhase.usageGraph => Symbols.search,
      ProgressPhase.analysis => Symbols.lightning,
    };
  }

  /// Start the overall analysis
  void start(String projectPath) {
    _totalStopwatch.start();

    stdout.writeln();
    final header = _bold(_color('  KNIPDART ', Colors.brightWhite));
    final subtitle = _dim('Unused Export Analyzer');
    stdout.writeln('$header $subtitle');
    stdout.writeln();

    final path = _color(projectPath, Colors.cyan);
    stdout.writeln('  ${_dim('Analyzing')} $path');
    stdout.writeln();
  }

  /// Start a new phase
  void startPhase(ProgressPhase phase, {int? totalFiles}) {
    if (_currentPhase != null) {
      _stopSpinner();
      _phaseDurations[_currentPhase!] = _phaseStopwatch.elapsed;
    }

    _currentPhase = phase;
    _phaseStopwatch.reset();
    _phaseStopwatch.start();
    _fileCount = totalFiles ?? 0;
    _currentFile = 0;

    final icon = _getPhaseIcon(phase);
    final message = _getPhaseMessage(phase);
    _startSpinner('$icon $message');
  }

  /// Update file progress
  void updateFileProgress(int current, {int? total}) {
    _currentFile = current;
    if (total != null) _fileCount = total;
  }

  /// Complete the current phase
  void completePhase({bool success = true}) {
    if (_currentPhase != null) {
      _stopSpinner(success: success);
      _phaseDurations[_currentPhase!] = _phaseStopwatch.elapsed;
      _currentPhase = null;
    }
  }

  /// Show a warning
  void warning(String message) {
    // Stop spinner temporarily
    _spinnerTimer?.cancel();
    stdout.write('\r\x1B[K');
    stdout.write(Cursor.show);

    final icon = _color(Symbols.warning, Colors.yellow);
    stdout.writeln('  $icon ${_color(message, Colors.yellow)}');

    // Restart spinner if we're in a phase
    if (_currentPhase != null) {
      stdout.write(Cursor.hide);
      _spinnerTimer = Timer.periodic(
        const Duration(milliseconds: 80),
        (_) => _updateSpinner(),
      );
    }
  }

  /// Show the final results
  void showResults({
    required int totalFiles,
    required int totalDeclarations,
    required int publicExports,
    required int unusedExports,
    required int usedOnlyInTests,
    required List<UnusedExportInfo> unused,
    required List<UnusedExportInfo> testOnly,
  }) {
    _totalStopwatch.stop();
    stdout.writeln();

    // Results header
    if (unusedExports == 0 && usedOnlyInTests == 0) {
      final icon = _color(Symbols.sparkles, Colors.green);
      stdout.writeln('  $icon ${_bold(_color('No unused exports found!', Colors.green))}');
    } else {
      // Unused exports section
      if (unused.isNotEmpty) {
        final icon = _color(Symbols.cross, Colors.red);
        final title = _bold(_color('Unused Exports', Colors.red));
        stdout.writeln('  $icon $title ${_dim('(${unused.length})')}');
        stdout.writeln();
        _printExportList(unused, Colors.red);
      }

      // Test-only exports section
      if (testOnly.isNotEmpty) {
        if (unused.isNotEmpty) stdout.writeln();
        final icon = _color(Symbols.warning, Colors.yellow);
        final title = _bold(_color('Used Only in Tests', Colors.yellow));
        stdout.writeln('  $icon $title ${_dim('(${testOnly.length})')}');
        stdout.writeln();
        _printExportList(testOnly, Colors.yellow);
      }
    }

    stdout.writeln();

    // Summary box
    _printSummaryBox(
      totalFiles: totalFiles,
      totalDeclarations: totalDeclarations,
      publicExports: publicExports,
      unusedExports: unusedExports,
      usedOnlyInTests: usedOnlyInTests,
    );
  }

  void _printExportList(List<UnusedExportInfo> exports, String color) {
    // Group by file
    final byFile = <String, List<UnusedExportInfo>>{};
    for (final export in exports) {
      byFile.putIfAbsent(export.filePath, () => []).add(export);
    }

    for (final entry in byFile.entries) {
      final filePath = entry.key;
      final fileExports = entry.value;

      stdout.writeln('    ${_color(filePath, Colors.white)}');

      for (var i = 0; i < fileExports.length; i++) {
        final export = fileExports[i];
        final isLast = i == fileExports.length - 1;
        final prefix = isLast ? '└──' : '├──';
        final prefixColored = _dim(prefix);

        final name = _color(export.name, color);
        final type = _dim('(${export.type})');

        stdout.writeln('    $prefixColored $name $type');
      }
    }
  }

  void _printSummaryBox({
    required int totalFiles,
    required int totalDeclarations,
    required int publicExports,
    required int unusedExports,
    required int usedOnlyInTests,
  }) {
    final elapsed = _formatDuration(_totalStopwatch.elapsed);

    // Calculate the unused percentage
    final unusedPercent = publicExports > 0
        ? ((unusedExports / publicExports) * 100).toStringAsFixed(1)
        : '0.0';

    stdout.writeln(_dim('  ┌─────────────────────────────────────┐'));
    stdout.writeln(_dim('  │') + _bold('           Summary                  ') + _dim('│'));
    stdout.writeln(_dim('  ├─────────────────────────────────────┤'));

    _printSummaryRow('Files analyzed', totalFiles.toString());
    _printSummaryRow('Total declarations', totalDeclarations.toString());
    _printSummaryRow('Public exports', publicExports.toString());

    final unusedStr = unusedExports > 0
        ? _color('$unusedExports ($unusedPercent%)', Colors.red)
        : _color('0', Colors.green);
    _printSummaryRow('Unused exports', unusedStr, raw: true);

    if (usedOnlyInTests > 0) {
      _printSummaryRow('Test-only', _color(usedOnlyInTests.toString(), Colors.yellow), raw: true);
    }

    stdout.writeln(_dim('  ├─────────────────────────────────────┤'));
    _printSummaryRow('Time', elapsed);
    stdout.writeln(_dim('  └─────────────────────────────────────┘'));
  }

  void _printSummaryRow(String label, String value, {bool raw = false}) {
    final labelPadded = label.padRight(18);
    final displayValue = raw ? value : _color(value, Colors.cyan);
    // Calculate visible length (excluding ANSI codes)
    final visibleLength = value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;
    final padding = 15 - visibleLength;
    final paddedValue = displayValue + ' ' * (padding > 0 ? padding : 0);
    stdout.writeln('${_dim('  │')}  $labelPadded$paddedValue${_dim('│')}');
  }
}

/// Simple info about an unused export for display
class UnusedExportInfo {
  final String filePath;
  final String name;
  final String type;

  UnusedExportInfo({
    required this.filePath,
    required this.name,
    required this.type,
  });
}
