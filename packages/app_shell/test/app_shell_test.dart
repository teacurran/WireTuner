import 'package:app_shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShell', () {
    test('can be instantiated', () {
      const shell = AppShell();
      expect(shell, isNotNull);
    });

    test('returns correct version', () {
      const shell = AppShell();
      expect(shell.version, equals('0.1.0'));
    });
  });
}
