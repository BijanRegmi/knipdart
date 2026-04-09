# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-01-XX

### Added
- Initial release of KnipDart
- AST-based analysis using the Dart `analyzer` package
- Detection of unused public exports
- Detection of exports used only in test files (separate category)
- Support for barrel files and re-exports
- Handling of `show`/`hide` combinators
- Handling of prefixed imports
- Console output with colored progress indicators and spinners
- JSON output format for CI integration
- CLI options:
  - `--format` - Output format (console/json)
  - `--exclude` - Glob patterns to exclude
  - `--verbose` - Verbose output
  - `--no-color` - Disable colors
  - `--no-spinner` - Disable spinner animation

### Technical Details
- Parses all Dart files in `lib/`, `bin/`, and `test/` directories
- Identifies public API as files in `lib/` (excluding `lib/src/`)
- Tracks symbol usage across all internal imports
- Excludes generated files (`*.g.dart`, `*.freezed.dart`) by default
