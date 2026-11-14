import 'package:flutter_test/flutter_test.dart';
import 'package:astramed/main.dart';

void main() {
  testWidgets('AstraMedApp loads dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AstraMedApp());
    expect(find.text('Monitor de Salud General'), findsOneWidget);
  });
}
