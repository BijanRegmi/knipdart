import 'package:knipdart/knipdart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Simple Project Analysis', () {
    late ProjectAnalyzer analyzer;
    late AnalysisResult result;

    setUpAll(() async {
      final fixturePath = p.join(
        p.current,
        'test',
        'fixtures',
        'simple_project',
      );
      analyzer = ProjectAnalyzer(projectPath: fixturePath);
      result = await analyzer.analyze();
    });

    test('finds unused exports', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();

      expect(unusedNames, contains('UnusedClass'));
      expect(unusedNames, contains('unusedFunction'));
      expect(unusedNames, contains('unusedConstant'));
    });

    test('does not report used exports as unused', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();

      expect(unusedNames, isNot(contains('UsedClass')));
      expect(unusedNames, isNot(contains('usedFunction')));
    });

    test('identifies exports used only in tests', () {
      final testOnlyNames = result.usedOnlyInTests
          .map((e) => e.declaration.name)
          .toSet();

      expect(testOnlyNames, contains('TestOnlyClass'));
    });

    test('provides correct statistics', () {
      expect(result.stats.totalFiles, equals(6));
      expect(result.stats.unusedExports, equals(3));
      expect(result.stats.usedOnlyInTests, equals(1));
    });
  });

  group('Combinators Project Analysis', () {
    late ProjectAnalyzer analyzer;
    late AnalysisResult result;

    setUpAll(() async {
      final fixturePath = p.join(
        p.current,
        'test',
        'fixtures',
        'combinators_project',
      );
      analyzer = ProjectAnalyzer(projectPath: fixturePath);
      result = await analyzer.analyze();
    });

    test('respects show combinators', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();

      // helper3 is not exported (filtered by show), should not be reported
      expect(unusedNames, isNot(contains('helper3')));

      // helper2 is exported but unused
      expect(unusedNames, contains('helper2'));
    });

    test('does not report used filtered exports', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();

      // helper1 is used
      expect(unusedNames, isNot(contains('helper1')));
    });
  });

  group('Local Usage Project Analysis', () {
    late ProjectAnalyzer analyzer;
    late AnalysisResult result;

    setUpAll(() async {
      final fixturePath = p.join(
        p.current,
        'test',
        'fixtures',
        'local_usage_project',
      );
      analyzer = ProjectAnalyzer(projectPath: fixturePath);
      result = await analyzer.analyze();
    });

    test('identifies exports used only locally', () {
      final localOnlyNames = result.usedOnlyLocally
          .map((e) => e.declaration.name)
          .toSet();

      // Foo is used only within the same file (by fooFromJson)
      // Baz is used only within the same file (by Foo.sayHello)
      expect(localOnlyNames, contains('Foo'));
      expect(localOnlyNames, contains('Baz'));
    });

    test('identifies completely unused exports', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();

      // Bar and Qux are not used anywhere
      expect(unusedNames, contains('Bar'));
      expect(unusedNames, contains('Qux'));
    });

    test('does not report externally used exports', () {
      final unusedNames = result.completelyUnused
          .map((e) => e.declaration.name)
          .toSet();
      final localOnlyNames = result.usedOnlyLocally
          .map((e) => e.declaration.name)
          .toSet();

      // fooFromJson is used in bin/main.dart
      expect(unusedNames, isNot(contains('fooFromJson')));
      expect(localOnlyNames, isNot(contains('fooFromJson')));
    });

    test('provides correct statistics', () {
      expect(result.stats.unusedExports, equals(2)); // Bar, Qux
      expect(result.stats.usedOnlyLocally, equals(2)); // Foo, Baz
    });
  });
}
