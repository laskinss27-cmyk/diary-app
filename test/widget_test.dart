import 'package:flutter_test/flutter_test.dart';
import 'package:diary_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DiaryApp());
    expect(find.text('🌸 Мой дневник'), findsOneWidget);
  });
}
