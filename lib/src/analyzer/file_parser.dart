import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as analyzer;
import 'package:analyzer/dart/ast/ast.dart';

import '../models/dart_file.dart';
import '../models/export_info.dart';
import '../models/import_info.dart';
import '../resolver/path_resolver.dart';
import 'declaration_collector.dart';

/// Parses a Dart file and extracts all metadata
class FileParser {
  final PathResolver pathResolver;

  FileParser(this.pathResolver);

  /// Parse a single Dart file
  Future<DartFile> parseDartFile(String filePath) async {
    final result = analyzer.parseFile(
      path: filePath,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
    final unit = result.unit;

    final collector = DeclarationCollector(filePath);
    unit.visitChildren(collector);

    final imports = <ImportInfo>[];
    final exports = <ExportInfo>[];
    final parts = <String>[];
    String? partOf;
    String? libraryName;

    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        imports.add(_parseImport(directive, filePath));
      } else if (directive is ExportDirective) {
        exports.add(_parseExport(directive, filePath));
      } else if (directive is PartDirective) {
        final resolvedPath = pathResolver.resolve(
          directive.uri.stringValue ?? '',
          fromFile: filePath,
        );
        if (resolvedPath != null) {
          parts.add(resolvedPath);
        }
      } else if (directive is PartOfDirective) {
        if (directive.uri != null) {
          partOf = pathResolver.resolve(
            directive.uri!.stringValue ?? '',
            fromFile: filePath,
          );
        } else if (directive.libraryName != null) {
          // Part of by library name - need to resolve later
          partOf = directive.libraryName!.name;
        }
      } else if (directive is LibraryDirective) {
        libraryName = directive.name2?.name;
      }
    }

    return DartFile(
      path: filePath,
      declarations: collector.declarations,
      imports: imports,
      exports: exports,
      parts: parts,
      partOf: partOf,
      libraryName: libraryName,
    );
  }

  ImportInfo _parseImport(ImportDirective directive, String sourceFile) {
    final uri = directive.uri.stringValue ?? '';
    final resolvedPath = pathResolver.resolve(uri, fromFile: sourceFile);
    final prefix = directive.prefix?.name;

    final showNames = <String>[];
    final hideNames = <String>[];

    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        showNames.addAll(combinator.shownNames.map((n) => n.name));
      } else if (combinator is HideCombinator) {
        hideNames.addAll(combinator.hiddenNames.map((n) => n.name));
      }
    }

    return ImportInfo(
      sourceFile: sourceFile,
      resolvedPath: resolvedPath,
      uri: uri,
      prefix: prefix,
      showNames: showNames,
      hideNames: hideNames,
      isDeferred: directive.deferredKeyword != null,
    );
  }

  ExportInfo _parseExport(ExportDirective directive, String sourceFile) {
    final uri = directive.uri.stringValue ?? '';
    final resolvedPath = pathResolver.resolve(uri, fromFile: sourceFile);

    final showNames = <String>[];
    final hideNames = <String>[];

    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        showNames.addAll(combinator.shownNames.map((n) => n.name));
      } else if (combinator is HideCombinator) {
        hideNames.addAll(combinator.hiddenNames.map((n) => n.name));
      }
    }

    return ExportInfo(
      sourceFile: sourceFile,
      resolvedPath: resolvedPath,
      uri: uri,
      showNames: showNames,
      hideNames: hideNames,
    );
  }
}
