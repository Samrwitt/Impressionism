import 'package:flutter_test/flutter_test.dart';
import 'package:impressionism_app/main.dart';

void main() {
  testWidgets('App shows simple era title', (WidgetTester tester) async {
    await tester.pumpWidget(const EraApp());
    expect(find.text('Art Era'), findsOneWidget);
  });
}
