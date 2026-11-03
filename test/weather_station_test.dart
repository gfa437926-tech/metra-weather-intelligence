import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/weather_station.dart';

void main() {
  group('WeatherStation', () {
    test('accepts valid geographic coordinates', () {
      const station = WeatherStation(
        id: 'station-1',
        name: 'محطة اختبار',
        type: StationType.automatic,
        latitude: 24.7136,
        longitude: 46.6753,
      );

      expect(station.hasValidCoordinates, isTrue);
      expect(station.typeLabel, 'آلية');
    });

    test('rejects latitude outside geographic bounds', () {
      const station = WeatherStation(
        id: 'station-2',
        name: 'محطة اختبار',
        type: StationType.classic,
        latitude: 91,
        longitude: 0,
      );

      expect(station.hasValidCoordinates, isFalse);
      expect(station.typeLabel, 'كلاسيكية');
    });

    test('rejects non-finite coordinates', () {
      const station = WeatherStation(
        id: 'station-3',
        name: 'محطة اختبار',
        type: StationType.classic,
        latitude: double.nan,
        longitude: double.infinity,
      );

      expect(station.hasValidCoordinates, isFalse);
    });

    test('compares station values structurally', () {
      const first = WeatherStation(
        id: 'same',
        name: 'محطة',
        type: StationType.classic,
        latitude: 10,
        longitude: 20,
      );
      const second = WeatherStation(
        id: 'same',
        name: 'محطة',
        type: StationType.classic,
        latitude: 10,
        longitude: 20,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
