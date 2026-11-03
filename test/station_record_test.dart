import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/station_record.dart';

void main() {
  StationRecord parse({
    String type = 'automatic',
    Object? latitude = 24.7136,
    Object? longitude = 46.6753,
  }) => StationRecord.fromJson({
    'id': 'station-1',
    'local_station_code': 'RYD-001',
    'name_ar': 'محطة اختبار',
    'station_type': type,
    'operational_status': 'active',
    'approval_status': 'approved',
    'latitude': latitude,
    'longitude': longitude,
  });

  test('parses numeric and string coordinates without losing valid locations', () {
    expect(parse().hasCoordinates, isTrue);
    expect(parse(latitude: '24.7136', longitude: '46.6753').hasCoordinates, isTrue);
  });

  test('rejects missing, non-numeric and out-of-range coordinates', () {
    expect(parse(latitude: null, longitude: null).hasCoordinates, isFalse);
    expect(parse(latitude: 'unknown', longitude: 46).hasCoordinates, isFalse);
    expect(parse(latitude: 91, longitude: 46).hasCoordinates, isFalse);
    expect(parse(latitude: 24, longitude: 181).hasCoordinates, isFalse);
  });

  test('distinguishes classic and automatic station types', () {
    expect(parse(type: 'classic').isClassic, isTrue);
    expect(parse(type: 'CLASSIC').isClassic, isTrue);
    expect(parse(type: 'automatic').isClassic, isFalse);
    expect(parse(type: 'automatic').typeLabel, 'آلية');
  });

  test('prefers a non-empty Arabic station name and falls back to English', () {
    final station = StationRecord.fromJson({
      'id': 1,
      'name_ar': '  ',
      'name_en': 'Riyadh Station',
      'station_type': 'automatic',
    });
    expect(station.name, 'Riyadh Station');
  });
}
