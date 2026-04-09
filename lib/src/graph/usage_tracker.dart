import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Tracks symbol usage within a file
class UsageScanner extends RecursiveAstVisitor<void> {
  /// Set of all identifiers used in the file
  final Set<String> usedIdentifiers = {};

  /// Map of prefix -> set of identifiers used with that prefix
  final Map<String, Set<String>> prefixedIdentifiers = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Skip declaration names - we only want references
    if (!_isDeclarationName(node)) {
      usedIdentifiers.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    final name = node.identifier.name;

    // The prefix could be an import alias OR a type name (enum, class)
    // At AST level (without semantic analysis), we can't distinguish
    // So track the prefix as both a used identifier AND in prefixedIdentifiers
    usedIdentifiers.add(prefix);
    prefixedIdentifiers.putIfAbsent(prefix, () => {}).add(name);

    // Don't call super - we've handled both parts
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Handle cases like: SomeClass.staticMethod
    // The target might be a SimpleIdentifier for class names
    if (node.target is SimpleIdentifier) {
      final target = node.target as SimpleIdentifier;
      // This could be a prefix or a class name
      usedIdentifiers.add(target.name);
      prefixedIdentifiers.putIfAbsent(target.name, () => {}).add(
        node.propertyName.name,
      );
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Type annotations like: MyClass, List<MyClass>
    if (node.importPrefix != null) {
      final prefix = node.importPrefix!.name.lexeme;
      prefixedIdentifiers.putIfAbsent(prefix, () => {}).add(node.name2.lexeme);
    } else {
      usedIdentifiers.add(node.name2.lexeme);
    }
    super.visitNamedType(node);
  }

  /// Check if an identifier is a declaration name (not a reference)
  bool _isDeclarationName(SimpleIdentifier node) {
    final parent = node.parent;

    if (parent is VariableDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is FunctionDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is MethodDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is ClassDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is EnumDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is MixinDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is ExtensionDeclaration && parent.name == node.token) {
      return true;
    }
    if (parent is TypeParameter && parent.name == node.token) {
      return true;
    }
    if (parent is FormalParameter) {
      // Parameter names
      return true;
    }

    return false;
  }
}

/// Tracks which declarations are used and where
class UsageTracker {
  /// Map of declaration ID -> set of files that use it
  final Map<String, Set<String>> _usages = {};

  /// Record that a declaration is used in a file
  void recordUsage(String declarationId, String usedInFile) {
    _usages.putIfAbsent(declarationId, () => {}).add(usedInFile);
  }

  /// Get all files that use a declaration
  Set<String> getUsages(String declarationId) {
    return _usages[declarationId] ?? {};
  }

  /// Check if a declaration is used anywhere
  bool isUsed(String declarationId) {
    return _usages.containsKey(declarationId) &&
        _usages[declarationId]!.isNotEmpty;
  }

  /// Check if a declaration is used only in test files
  bool isUsedOnlyInTests(
    String declarationId,
    bool Function(String path) isTestFile,
  ) {
    final usages = _usages[declarationId];
    if (usages == null || usages.isEmpty) return false;
    return usages.every(isTestFile);
  }
}
