// Smoke test that the app builds.

import 'package:flutter_test/flutter_test.dart';

import 'package:careme/main.dart';

void main() {
  testWidgets('App boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const CareMeApp());
  });
}
