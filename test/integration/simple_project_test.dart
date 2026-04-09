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
}
