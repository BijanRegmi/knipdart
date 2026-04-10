# KnipDart

[![CI](https://github.com/BijanRegmi/knipdart/actions/workflows/ci.yml/badge.svg)](https://github.com/BijanRegmi/knipdart/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Find unused exports in Dart/Flutter projects.

Inspired by [knip.dev](https://knip.dev) for JavaScript/TypeScript.

> [!NOTE]
> I needed this for a project and couldn't find a tool that worked, so I just had Claude Code build it for me. I didn't actually write any of this. Claude did all the work. Consider it an "exported" task that, unlike most, actually ended up being useful. Posting it here in case anyone else wants it.

## Features

- **AST-based analysis** - Uses the Dart `analyzer` package for accurate detection
- **Finds unused exports** - Public API declarations that are never imported
- **Identifies test-only exports** - Exports used only in test files (separate category)
- **Handles barrel files** - Correctly traces re-exports through barrel files
- **Respects combinators** - Handles `show` and `hide` in exports
- **Multiple output formats** - Console (with colors & spinners) and JSON
- **Cross-platform** - Works on Linux, macOS, and Windows

## Installation

### From GitHub

```bash
# Install globally
dart pub global activate --source git https://github.com/BijanRegmi/knipdart

# Or add to dev_dependencies
# pubspec.yaml
dev_dependencies:
  knipdart:
    git:
      url: https://github.com/BijanRegmi/knipdart
      ref: v0.1.0
```

### From source

```bash
git clone https://github.com/BijanRegmi/knipdart
cd knipdart
dart pub global activate --source path .
```

### Download binary

Pre-built executables are available on the [Releases](https://github.com/BijanRegmi/knipdart/releases) page.

## Usage

```bash
# Analyze current directory
knipdart analyze

# Analyze specific path
knipdart analyze /path/to/project

# JSON output (for CI)
knipdart analyze --format=json

# Verbose output (shows export paths)
knipdart analyze --verbose

# Exclude patterns
knipdart analyze --exclude="**/*.g.dart" --exclude="**/*.freezed.dart"

# Disable colors/spinner (for CI)
knipdart analyze --no-color --no-spinner
```

## Example Output

```
  KNIPDART  Unused Export Analyzer

  Analyzing my_project

  ✓ 📁 Discovering project structure (25ms)
  ✓ 📄 Parsing Dart files (230ms)
  ✓ 🔗 Building export graph (5ms)
  ✓ 🔍 Analyzing symbol usage (45ms)
  ✓ ⚡ Finding unused exports (2ms)

  ✗ Unused Exports (3)

    lib/src/utils/string_helpers.dart
    ├── capitalize (function)
    └── truncateWithEllipsis (function)

    lib/src/models/legacy_user.dart
    └── LegacyUser (class)

  ⚠ Used Only in Tests (1)

    lib/src/testing/mock_helpers.dart
    └── MockHelper (class)

  ┌─────────────────────────────────────┐
  │           Summary                   │
  ├─────────────────────────────────────┤
  │  Files analyzed    47               │
  │  Total declarations234              │
  │  Public exports    89               │
  │  Unused exports    3 (3.4%)         │
  │  Test-only         1                │
  ├─────────────────────────────────────┤
  │  Time              312ms            │
  └─────────────────────────────────────┘
```

## CI Integration

Add to your GitHub Actions workflow:

```yaml
- name: Check for unused exports
  run: |
    dart pub global activate --source git https://github.com/BijanRegmi/knipdart
    knipdart analyze --no-spinner --no-color
```

Or use JSON output for parsing:

```yaml
- name: Check for unused exports
  run: |
    dart pub global activate --source git https://github.com/BijanRegmi/knipdart
    knipdart analyze --format=json > unused-exports.json
    if [ $(jq '.stats.unusedExports' unused-exports.json) -gt 0 ]; then
      echo "Found unused exports!"
      exit 1
    fi
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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`dart test`)
4. Run the analyzer on itself (`dart run bin/knipdart.dart analyze .`)
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Releasing

Releases are automated via GitHub Actions:

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md` with the new version
3. Commit: `git commit -am "Release v0.x.0"`
4. Tag: `git tag v0.x.0`
5. Push: `git push && git push --tags`

The release workflow will automatically:
- Run tests
- Create a GitHub release with changelog
- Build and attach executables for Linux, macOS, and Windows

## License

MIT
