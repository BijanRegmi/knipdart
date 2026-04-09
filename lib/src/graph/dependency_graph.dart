import '../models/dart_file.dart';
import '../models/declaration.dart';

/// Tracks which declarations are part of the public API
class PublicApiTracker {
  /// Set of declaration IDs that are part of the public API
  final Set<String> _publicApi = {};

  /// Map of declaration ID -> the public API file it's exported from
  final Map<String, String> _exportedVia = {};

  /// Mark a declaration as part of the public API
  void addPublicDeclaration(Declaration declaration, {String? exportedVia}) {
    _publicApi.add(declaration.id);
    if (exportedVia != null) {
      _exportedVia[declaration.id] = exportedVia;
    }
  }

  /// Check if a declaration is part of the public API
  bool isPublicApi(String declarationId) {
    return _publicApi.contains(declarationId);
  }

  /// Get the file through which a declaration is exported
  String? getExportedVia(String declarationId) {
    return _exportedVia[declarationId];
  }

  /// Get all public API declaration IDs
  Set<String> get allPublicApiIds => Set.unmodifiable(_publicApi);
}

/// Holds all parsed files and provides lookup
class ProjectGraph {
  final Map<String, DartFile> _files = {};

  /// Add a parsed file to the graph
  void addFile(DartFile file) {
    _files[file.path] = file;
  }

  /// Get a file by path
  DartFile? getFile(String path) => _files[path];

  /// Get all files
  Iterable<DartFile> get allFiles => _files.values;

  /// Get all file paths
  Iterable<String> get allPaths => _files.keys;

  /// Get all declarations across all files
  Iterable<Declaration> get allDeclarations =>
      _files.values.expand((f) => f.declarations);

  /// Get declarations by name (may be multiple if same name in different files)
  List<Declaration> getDeclarationsByName(String name) {
    return allDeclarations.where((d) => d.name == name).toList();
  }
}
