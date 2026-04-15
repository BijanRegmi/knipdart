import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart' hide AnalysisResult;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../graph/dependency_graph.dart';
import '../graph/usage_tracker.dart';
import '../models/analysis_result.dart';
import '../models/dart_file.dart';
import '../models/declaration.dart';
import '../resolver/path_resolver.dart';
import 'file_parser.dart';

/// Progress callback for analysis phases
typedef ProgressCallback = void Function(AnalysisProgress progress);

/// Analysis progress information
class AnalysisProgress {
  final AnalysisPhase phase;
  final int? currentFile;
  final int? totalFiles;
  final String? message;

  const AnalysisProgress({
    required this.phase,
    this.currentFile,
    this.totalFiles,
    this.message,
  });
}

/// Analysis phases
enum AnalysisPhase {
  discovery,
  parsing,
  exportGraph,
  usageGraph,
  findingUnused,
  complete,
}

/// Main analyzer that orchestrates the analysis
class ProjectAnalyzer {
  final String projectPath;
  final List<String> excludePatterns;
  final List<String> scopePaths;
  final bool verbose;
  final ProgressCallback? onProgress;

  late final String _packageName;
  late final PathResolver _pathResolver;
  late final FileParser _fileParser;
  late final ProjectGraph _projectGraph;
  late final PublicApiTracker _publicApi;
  late final UsageTracker _usageTracker;
  late final AnalysisContextCollection _contextCollection;

  final List<AnalysisWarning> _warnings = [];

  ProjectAnalyzer({
    required this.projectPath,
    this.excludePatterns = const [],
    this.scopePaths = const [],
    this.verbose = false,
    this.onProgress,
  });

  void _reportProgress(AnalysisPhase phase, {int? current, int? total, String? message}) {
    onProgress?.call(AnalysisProgress(
      phase: phase,
      currentFile: current,
      totalFiles: total,
      message: message,
    ),);
  }

  /// Run the full analysis
  Future<AnalysisResult> analyze() async {
    final stopwatch = Stopwatch()..start();

    // Phase 1: Project Discovery
    _reportProgress(AnalysisPhase.discovery);
    await _discoverProject();

    // Phase 2: Parse all files
    _reportProgress(AnalysisPhase.parsing);
    await _parseAllFiles();

    // Phase 3: Build export graph (identify public API)
    _reportProgress(AnalysisPhase.exportGraph);
    _buildExportGraph();

    // Phase 4: Build usage graph
    _reportProgress(AnalysisPhase.usageGraph);
    _buildUsageGraph();

    // Phase 5: Identify unused exports
    _reportProgress(AnalysisPhase.findingUnused);
    final unusedExports = _findUnusedExports();

    _reportProgress(AnalysisPhase.complete);
    stopwatch.stop();

    final stats = AnalysisStats(
      totalFiles: _projectGraph.allFiles.length,
      totalDeclarations: _projectGraph.allDeclarations.length,
      publicDeclarations: _publicApi.allPublicApiIds.length,
      unusedExports:
          unusedExports.where((e) => e.category == UnusedCategory.unused).length,
      usedOnlyLocally: unusedExports
          .where((e) => e.category == UnusedCategory.usedOnlyLocally)
          .length,
      usedOnlyInTests: unusedExports
          .where((e) => e.category == UnusedCategory.usedOnlyInTests)
          .length,
      analysisTime: stopwatch.elapsed,
    );

    return AnalysisResult(
      unusedExports: unusedExports,
      stats: stats,
      warnings: _warnings,
    );
  }

  /// Phase 1: Discover project structure
  Future<void> _discoverProject() async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      throw Exception('No pubspec.yaml found in $projectPath');
    }

    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    _packageName = pubspec['name'] as String;

    final absoluteProjectRoot = p.normalize(p.absolute(projectPath));

    _pathResolver = PathResolver(
      packageName: _packageName,
      projectRoot: absoluteProjectRoot,
    );

    // Create analysis context that respects project's analysis_options.yaml
    _contextCollection = AnalysisContextCollection(
      includedPaths: [absoluteProjectRoot],
    );

    _fileParser = FileParser(_pathResolver, _contextCollection);
    _projectGraph = ProjectGraph();
    _publicApi = PublicApiTracker();
    _usageTracker = UsageTracker();
  }

  /// Phase 2: Parse all Dart files
  Future<void> _parseAllFiles() async {
    final dartFiles = await _findDartFiles();
    final total = dartFiles.length;
    var current = 0;

    for (final filePath in dartFiles) {
      current++;
      _reportProgress(AnalysisPhase.parsing, current: current, total: total);

      if (_shouldExclude(filePath)) continue;

      try {
        final dartFile = _fileParser.parseDartFile(filePath);
        _projectGraph.addFile(dartFile);
      } catch (e) {
        _warnings.add(AnalysisWarning('Failed to parse: $e', filePath));
      }
    }
  }

  /// Find all Dart files in the project
  Future<List<String>> _findDartFiles() async {
    final files = <String>[];
    final glob = Glob('**.dart');
    final absoluteProjectPath = p.normalize(p.absolute(projectPath));

    // Search in lib/, bin/, test/
    for (final dir in ['lib', 'bin', 'test']) {
      final dirPath = p.join(absoluteProjectPath, dir);
      if (!Directory(dirPath).existsSync()) continue;

      await for (final entity in glob.list(root: dirPath)) {
        if (entity is File) {
          files.add(p.normalize(entity.path));
        }
      }
    }

    return files;
  }

  /// Check if a file should be excluded
  bool _shouldExclude(String filePath) {
    final relativePath = _pathResolver.relativePath(filePath);

    for (final pattern in excludePatterns) {
      if (Glob(pattern).matches(relativePath)) {
        return true;
      }
    }

    // Exclude generated files by default
    if (relativePath.endsWith('.g.dart') ||
        relativePath.endsWith('.freezed.dart')) {
      return true;
    }

    return false;
  }

  /// Phase 3: Build the export graph
  void _buildExportGraph() {
    // Find all public API files (lib/ but not lib/src/)
    final publicApiFiles = _projectGraph.allFiles.where((file) {
      return _pathResolver.isInLib(file.path) &&
          !_pathResolver.isInLibSrc(file.path) &&
          !file.isPartFile;
    });

    for (final file in publicApiFiles) {
      _processPublicApiFile(file, file.path);
    }
  }

  /// Check if a file is within the analysis scope
  bool _isInScope(String filePath) {
    if (scopePaths.isEmpty) return true;

    final normalizedPath = p.normalize(p.absolute(filePath));
    for (final scope in scopePaths) {
      final normalizedScope = p.normalize(p.absolute(scope));
      if (p.isWithin(normalizedScope, normalizedPath) ||
          normalizedPath == normalizedScope) {
        return true;
      }
    }
    return false;
  }

  /// Process a public API file and its exports
  void _processPublicApiFile(DartFile file, String publicApiPath) {
    final visited = <String>{};
    _processExportsRecursively(file, publicApiPath, visited, null);
  }

  void _processExportsRecursively(
    DartFile file,
    String publicApiPath,
    Set<String> visited,
    Set<String>? allowedNames,
  ) {
    if (visited.contains(file.path)) return;
    visited.add(file.path);

    // Add this file's public declarations to public API
    // If allowedNames is set, only add those names (for filtered re-exports)
    for (final decl in file.publicDeclarations) {
      if (allowedNames != null && !allowedNames.contains(decl.name)) continue;
      _publicApi.addPublicDeclaration(
        decl,
        exportedVia: publicApiPath != file.path ? publicApiPath : null,
      );
    }

    // Process re-exports from this file
    for (final export in file.exports) {
      if (!export.isInternalExport) continue;

      final exportedFile = _projectGraph.getFile(export.resolvedPath!);
      if (exportedFile == null) continue;

      // Apply show/hide combinators
      // Include part file declarations when computing available names
      final availableNames = <String>{...exportedFile.publicDeclarationNames};
      for (final partPath in exportedFile.parts) {
        final partFile = _projectGraph.getFile(partPath);
        if (partFile != null) {
          availableNames.addAll(partFile.publicDeclarationNames);
        }
      }
      var exportedNames = export.getExportedNames(availableNames);

      // If we have allowedNames from parent, intersect with that
      if (allowedNames != null) {
        exportedNames = exportedNames.intersection(allowedNames);
      }

      // Recursively process with the filtered names
      _processExportsRecursively(
        exportedFile,
        publicApiPath,
        visited,
        exportedNames,
      );
    }

    // Process part files
    for (final partPath in file.parts) {
      final partFile = _projectGraph.getFile(partPath);
      if (partFile == null) continue;

      for (final decl in partFile.publicDeclarations) {
        if (allowedNames != null && !allowedNames.contains(decl.name)) continue;
        _publicApi.addPublicDeclaration(
          decl,
          exportedVia: publicApiPath != partFile.path ? publicApiPath : null,
        );
      }
    }
  }

  /// Phase 4: Build usage graph
  void _buildUsageGraph() {
    for (final file in _projectGraph.allFiles) {
      _analyzeFileUsage(file);
    }
  }

  /// Analyze symbol usage within a file
  void _analyzeFileUsage(DartFile file) {
    // Parse the file using the project's analysis context
    final context = _contextCollection.contextFor(file.path);
    final result = context.currentSession.getParsedUnit(file.path);

    if (result is! ParsedUnitResult) {
      _warnings.add(AnalysisWarning('Failed to parse for usage', file.path));
      return;
    }

    final scanner = UsageScanner();
    result.unit.visitChildren(scanner);

    // Build a map of available names from imports
    final importedNames = <String, Set<Declaration>>{};
    final prefixedImports = <String, Map<String, Set<Declaration>>>{};

    for (final import in file.imports) {
      if (!import.isInternalImport) continue;

      final importedFile = _projectGraph.getFile(import.resolvedPath!);
      if (importedFile == null) continue;

      // Get declarations available from this import (including re-exports)
      final available = _getAvailableDeclarations(importedFile);
      final importedDecls = import.getImportedNames(
        available.map((d) => d.name).toSet(),
      );

      for (final decl in available) {
        if (!importedDecls.contains(decl.name)) continue;

        if (import.prefix != null) {
          // Prefixed import
          prefixedImports
              .putIfAbsent(import.prefix!, () => {})
              .putIfAbsent(decl.name, () => {})
              .add(decl);
        } else {
          // Non-prefixed import
          importedNames.putIfAbsent(decl.name, () => {}).add(decl);
        }
      }
    }

    // Match usage to declarations from imports
    for (final name in scanner.usedIdentifiers) {
      final decls = importedNames[name];
      if (decls != null) {
        for (final decl in decls) {
          _usageTracker.recordUsage(decl.id, file.path);
        }
      }
    }

    // Match prefixed usage
    for (final entry in scanner.prefixedIdentifiers.entries) {
      final prefix = entry.key;
      final names = entry.value;

      final prefixDecls = prefixedImports[prefix];
      if (prefixDecls == null) continue;

      for (final name in names) {
        final decls = prefixDecls[name];
        if (decls != null) {
          for (final decl in decls) {
            _usageTracker.recordUsage(decl.id, file.path);
          }
        }
      }
    }

    // Track self-file/library usage (declarations used within the same file or library)
    // Collect all declarations in this library (file + its part files)
    final libraryDeclarations = <Declaration>[...file.declarations];
    for (final partPath in file.parts) {
      final partFile = _projectGraph.getFile(partPath);
      if (partFile != null) {
        libraryDeclarations.addAll(partFile.declarations);
      }
    }

    // If this is a part file, also include the parent library's declarations
    if (file.isPartFile && file.partOf != null) {
      final parentFile = _projectGraph.getFile(file.partOf!);
      if (parentFile != null) {
        libraryDeclarations.addAll(parentFile.declarations);
        // And other parts of the same library
        for (final partPath in parentFile.parts) {
          if (partPath != file.path) {
            final siblingPart = _projectGraph.getFile(partPath);
            if (siblingPart != null) {
              libraryDeclarations.addAll(siblingPart.declarations);
            }
          }
        }
      }
    }

    // Track usage against all declarations in the library
    // For same-library usage, record using the declaration's own file path
    // This ensures "used only locally" works correctly for part files
    for (final name in scanner.usedIdentifiers) {
      for (final decl in libraryDeclarations) {
        if (decl.name == name) {
          _usageTracker.recordUsage(decl.id, decl.filePath);
        }
      }
    }
  }

  /// Get all declarations available from a file (including re-exports)
  Set<Declaration> _getAvailableDeclarations(DartFile file) {
    final result = <Declaration>{};
    final visited = <String>{};

    void collect(DartFile f) {
      if (visited.contains(f.path)) return;
      visited.add(f.path);

      result.addAll(f.publicDeclarations);

      // Include re-exported declarations
      for (final export in f.exports) {
        if (!export.isInternalExport) continue;
        final exportedFile = _projectGraph.getFile(export.resolvedPath!);
        if (exportedFile == null) continue;

        final availableNames = _getAvailableDeclarations(exportedFile)
            .map((d) => d.name)
            .toSet();
        final exportedNames = export.getExportedNames(availableNames);

        for (final decl in exportedFile.publicDeclarations) {
          if (exportedNames.contains(decl.name)) {
            result.add(decl);
          }
        }

        collect(exportedFile);
      }

      // Include part file declarations
      for (final partPath in f.parts) {
        final partFile = _projectGraph.getFile(partPath);
        if (partFile != null) {
          result.addAll(partFile.publicDeclarations);
        }
      }
    }

    collect(file);
    return result;
  }

  /// Phase 5: Find unused exports
  List<UnusedExport> _findUnusedExports() {
    final unused = <UnusedExport>[];

    for (final declarationId in _publicApi.allPublicApiIds) {
      // Find the actual declaration
      final parts = declarationId.split('#');
      final filePath = parts[0];
      final name = parts[1];

      // Skip if not in scope
      if (!_isInScope(filePath)) continue;

      final file = _projectGraph.getFile(filePath);
      if (file == null) continue;

      final declaration = file.declarations.firstWhere(
        (d) => d.name == name,
        orElse: () => Declaration(
          filePath: filePath,
          name: name,
          type: DeclarationType.classDeclaration,
          lineNumber: 0,
          column: 0,
        ),
      );

      if (_usageTracker.isUsedOnlyInTests(
        declarationId,
        _pathResolver.isTestFile,
      )) {
        unused.add(UnusedExport(
          declaration: declaration,
          exportedVia: _publicApi.getExportedVia(declarationId),
          category: UnusedCategory.usedOnlyInTests,
        ),);
      } else if (_usageTracker.isUsedOnlyLocally(declarationId)) {
        unused.add(UnusedExport(
          declaration: declaration,
          exportedVia: _publicApi.getExportedVia(declarationId),
          category: UnusedCategory.usedOnlyLocally,
        ),);
      } else if (!_usageTracker.isUsed(declarationId)) {
        unused.add(UnusedExport(
          declaration: declaration,
          exportedVia: _publicApi.getExportedVia(declarationId),
          category: UnusedCategory.unused,
        ),);
      }
    }

    // Sort by file path, then by name
    unused.sort((a, b) {
      final pathCompare =
          a.declaration.filePath.compareTo(b.declaration.filePath);
      if (pathCompare != 0) return pathCompare;
      return a.declaration.name.compareTo(b.declaration.name);
    });

    return unused;
  }
}
