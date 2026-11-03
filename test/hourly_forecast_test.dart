import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/data/weather_service.dart';
void main() {
 test('hourly forecast maps weather symbols and local hour labels', () {
  final forecast=HourlyForecast(time:DateTime(2026,11,3,14),temperature:28.6,weatherCode:2);
  expect(forecast.label,'14:00');
  expect(forecast.symbol,'⛅');
  expect(forecast.temperature.round(),29);
 });
}
