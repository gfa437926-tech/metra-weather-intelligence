import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/station_record.dart';

void main() {
  group('StationRecord.fromJson', () {
    test('parses Arabic name, station type and numeric coordinate strings', () {
      final station = StationRecord.fromJson({
        'id': 'id-1',
        'local_station_code': 'R-001',
        'name_ar': ' محطة تجريبية ',
        'name_en': 'Test Station',
        'station_type': 'classic',
        'operational_status': 'active',
        'approval_status': 'approved',
        'latitude': '24.7',
        'longitude': 46.6,
      });
      expect(station.name, 'محطة تجريبية');
      expect(station.typeLabel, 'كلاسيكية');
      expect(station.hasCoordinates, isTrue);
      expect(station.approvalLabel, 'معتمدة');
    });

    test('keeps missing coordinates absent and does not invent a map location', () {
      final station = StationRecord.fromJson({
        'id': 'id-2',
        'local_station_code': 'R-002',
        'name_ar': 'محطة دون إحداثيات',
        'station_type': 'automatic',
        'operational_status': 'unverified',
        'approval_status': 'pending',
      });
      expect(station.latitude, isNull);
      expect(station.longitude, isNull);
      expect(station.hasCoordinates, isFalse);
      expect(station.approvalLabel, 'بانتظار الاعتماد');
    });

    test('rejects out-of-range coordinates for map rendering', () {
      final station = StationRecord.fromJson({
        'id': 'id-3',
        'name_ar': 'محطة',
        'station_type': 'automatic',
        'latitude': 95,
        'longitude': 181,
      });
      expect(station.hasCoordinates, isFalse);
    });

    test('maps requested changes status to Arabic label', () {
      final station = StationRecord.fromJson({
        'id': 'id-4',
        'station_type': 'classic',
        'approval_status': 'changes_requested',
      });
      expect(station.approvalLabel, 'تحتاج إلى تعديل');
    });
  });
}
