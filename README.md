# KnipDart

Find unused exports in Dart/Flutter projects.

Inspired by [knip.dev](https://knip.dev) for JavaScript/TypeScript.

## Features

- **AST-based analysis** - Uses the Dart `analyzer` package for accurate detection
- **Finds unused exports** - Public API declarations that are never imported
- **Identifies test-only exports** - Exports used only in test files (separate category)
- **Handles barrel files** - Correctly traces re-exports through barrel files
- **Respects combinators** - Handles `show` and `hide` in exports
- **Multiple output formats** - Console and JSON

## Installation

```bash
dart pub global activate --source path .
```

Or add to your `dev_dependencies`:

```yaml
dev_dependencies:
  knipdart:
    path: ../knipdart
```

## Usage

```bash
# Analyze current directory
knipdart analyze

# Analyze specific path
knipdart analyze /path/to/project

# JSON output
knipdart analyze --format=json

# Verbose output (shows export paths)
knipdart analyze --verbose

# Exclude patterns
knipdart analyze --exclude="**/*.g.dart" --exclude="**/*.freezed.dart"
```

## Example Output

```
Unused exports (3):

lib/src/utils/string_helpers.dart
  ├── capitalize (function)
  └── truncateWithEllipsis (function)

lib/src/models/legacy_user.dart
  └── LegacyUser (class)

Used only in tests (1):

lib/src/testing/mock_helpers.dart
  └── MockHelper (class)

Summary:
  Total files: 47
  Total declarations: 234
  Public exports: 89
  Unused exports: 3
  Used only in tests: 1

Analysis completed in 245ms
```

## How It Works

1. **Project Discovery** - Locates `pubspec.yaml` and identifies the package
2. **File Parsing** - Parses all Dart files using the `analyzer` package
3. **Export Graph** - Builds a graph of public API exports (from `lib/` excluding `lib/src/`)
4. **Usage Tracking** - Scans all files for import usage
5. **Analysis** - Identifies exports that are never imported

## What Counts as "Public API"

- Files directly in `lib/` (not in `lib/src/`)
- Declarations re-exported via `export` directives from public files
- Generated files (`*.g.dart`, `*.freezed.dart`) are excluded by default

## Programmatic Usage

```dart
import 'package:knipdart/knipdart.dart';

void main() async {
  final analyzer = ProjectAnalyzer(
    projectPath: '/path/to/project',
    excludePatterns: ['**/*.g.dart'],
  );

  final result = await analyzer.analyze();

  print('Unused exports: ${result.stats.unusedExports}');
  print('Used only in tests: ${result.stats.usedOnlyInTests}');

  for (final export in result.completelyUnused) {
    print('${export.declaration.name} in ${export.declaration.filePath}');
  }
}
```

## License

MIT
