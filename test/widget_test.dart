import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/main.dart';

void main() {
  testWidgets('METRA shell renders Arabic navigation and weather overview', (tester) async {
    await tester.pumpWidget(const MetraWeatherApp());
    expect(find.text('METRA'), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('الخريطة'), findsWidgets);
    expect(find.text('المحطات'), findsWidgets);
    expect(find.text('التنبيهات'), findsWidgets);
    expect(find.text('الإعدادات'), findsWidgets);
  });

  testWidgets('station directory does not label placeholder records as live', (tester) async {
    await tester.pumpWidget(const MetraWeatherApp());
    await tester.tap(find.text('المحطات').last);
    await tester.pumpAndSettle();
    expect(find.text('محطات الرصد'), findsOneWidget);
    expect(find.text('خدمة المحطات غير مهيأة'), findsOneWidget);
    expect(find.text('محطة الرياض'), findsNothing);
  });
}

