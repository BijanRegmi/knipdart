import 'declaration.dart';
import 'export_info.dart';
import 'import_info.dart';

/// Represents a parsed Dart file with all its metadata
class DartFile {
  /// Absolute path to the file
  final String path;

  /// All declarations in this file
  final List<Declaration> declarations;

  /// All import directives
  final List<ImportInfo> imports;

  /// All export directives (re-exports)
  final List<ExportInfo> exports;

  /// Part file paths (resolved absolute paths)
  final List<String> parts;

  /// Part-of library path (if this is a part file)
  final String? partOf;

  /// Library name (if specified with library directive)
  final String? libraryName;

  const DartFile({
    required this.path,
    required this.declarations,
    required this.imports,
    required this.exports,
    this.parts = const [],
    this.partOf,
    this.libraryName,
  });

  /// Whether this file is a part file
  bool get isPartFile => partOf != null;

  /// All public declaration names
  Set<String> get publicDeclarationNames =>
      declarations.where((d) => d.isPublic).map((d) => d.name).toSet();

  /// All public declarations
  List<Declaration> get publicDeclarations =>
      declarations.where((d) => d.isPublic).toList();

  @override
  String toString() => 'DartFile($path, ${declarations.length} declarations)';
}
