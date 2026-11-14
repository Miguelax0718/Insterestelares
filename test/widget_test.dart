import 'package:flutter_test/flutter_test.dart';
import 'package:astramed/main.dart';

void main() {
  testWidgets('AstraMedApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AstraMedApp());
    expect(find.text('AstraMed Operational'), findsOneWidget);
  });
}
