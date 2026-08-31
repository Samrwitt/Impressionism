import 'package:flutter_test/flutter_test.dart';
import 'package:impressionism_app/main.dart';

void main() {
  testWidgets('App loads cleanly test', (WidgetTester tester) async {
    await tester.pumpWidget(const ImpressionismApp());
    expect(find.text('Impressionist AI'), findsOneWidget);
  });
}
