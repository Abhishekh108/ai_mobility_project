import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('AI Mobility App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AIMobilityApp());
    expect(find.byType(AIMobilityApp), findsOneWidget);
  });
}
