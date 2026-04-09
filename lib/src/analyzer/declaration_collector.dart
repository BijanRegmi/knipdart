import 'package:analyzer/dart/ast/ast.dart' hide Declaration;
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/declaration.dart';

/// AST visitor that collects all declarations from a file
class DeclarationCollector extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Declaration> declarations = [];

  DeclarationCollector(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.classDeclaration,
      lineNumber: node.name.offset,
      column: 0,
    ));
    // Don't visit children - we only want top-level declarations
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.mixin,
      lineNumber: node.name.offset,
      column: 0,
    ));
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.enumDeclaration,
      lineNumber: node.name.offset,
      column: 0,
    ));
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    // Extensions may be unnamed
    final name = node.name?.lexeme;
    if (name != null) {
      declarations.add(Declaration(
        filePath: filePath,
        name: name,
        type: DeclarationType.extension,
        lineNumber: node.name!.offset,
        column: 0,
      ));
    }
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.extensionType,
      lineNumber: node.name.offset,
      column: 0,
    ));
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Only top-level functions
    if (node.parent is CompilationUnit) {
      declarations.add(Declaration(
        filePath: filePath,
        name: node.name.lexeme,
        type: DeclarationType.functionDeclaration,
        lineNumber: node.name.offset,
        column: 0,
      ));
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      declarations.add(Declaration(
        filePath: filePath,
        name: variable.name.lexeme,
        type: DeclarationType.topLevelVariable,
        lineNumber: variable.name.offset,
        column: 0,
      ));
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.typedef,
      lineNumber: node.name.offset,
      column: 0,
    ));
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    declarations.add(Declaration(
      filePath: filePath,
      name: node.name.lexeme,
      type: DeclarationType.typedef,
      lineNumber: node.name.offset,
      column: 0,
    ));
  }
}
