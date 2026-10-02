import 'package:flutter_test/flutter_test.dart';
import 'package:aegismind_frontend/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const AegisMindApp());
    expect(find.text('I NEED HELP'), findsOneWidget);
  });
}
