/// Type of declaration
enum DeclarationType {
  classDeclaration,
  functionDeclaration,
  topLevelVariable,
  typedef,
  enumDeclaration,
  extension,
  extensionType,
  mixin,
}

/// Represents a public declaration that could be exported
class Declaration {
  /// The file where this declaration lives
  final String filePath;

  /// Name of the declaration
  final String name;

  /// Type of declaration
  final DeclarationType type;

  /// Line number for reporting
  final int lineNumber;

  /// Column number for reporting
  final int column;

  const Declaration({
    required this.filePath,
    required this.name,
    required this.type,
    required this.lineNumber,
    required this.column,
  });

  /// Unique identifier combining file path and name
  String get id => '$filePath#$name';

  /// Whether this is public (doesn't start with _)
  bool get isPublic => !name.startsWith('_');

  @override
  String toString() => 'Declaration($name, $type, $filePath:$lineNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Declaration &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          name == other.name;

  @override
  int get hashCode => Object.hash(filePath, name);
}
