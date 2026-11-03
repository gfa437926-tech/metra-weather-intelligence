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
    expect(parse(latitude: ' 24.7136 ', longitude: ' 46.6753 ').hasCoordinates, isTrue);
  });

  test('rejects missing, empty, non-numeric and out-of-range coordinates', () {
    expect(parse(latitude: null, longitude: null).hasCoordinates, isFalse);
    expect(parse(latitude: '', longitude: ' ').hasCoordinates, isFalse);
    expect(parse(latitude: 'unknown', longitude: 46).hasCoordinates, isFalse);
    expect(parse(latitude: 91, longitude: 46).hasCoordinates, isFalse);
    expect(parse(latitude: 24, longitude: 181).hasCoordinates, isFalse);
    expect(parse(latitude: double.nan, longitude: 46).hasCoordinates, isFalse);
  });

  test('distinguishes classic and automatic station types', () {
    expect(parse(type: 'classic').isClassic, isTrue);
    expect(parse(type: 'CLASSIC').isClassic, isTrue);
    expect(parse(type: ' automatic ').isAutomatic, isTrue);
    expect(parse(type: 'automatic').typeLabel, 'آلية');
  });

  test('does not mislabel unknown station types as automatic', () {
    final station = parse(type: 'legacy_sensor');
    expect(station.isClassic, isFalse);
    expect(station.isAutomatic, isFalse);
    expect(station.typeLabel, 'نوع غير معروف');
  });

  test('prefers a non-empty Arabic station name and trims values', () {
    final station = StationRecord.fromJson({
      'id': ' 1 ',
      'local_station_code': ' RYD-001 ',
      'name_ar': '  ',
      'name_en': ' Riyadh Station ',
      'station_type': 'automatic',
    });
    expect(station.id, '1');
    expect(station.code, 'RYD-001');
    expect(station.name, 'Riyadh Station');
  });

  test('normalizes and labels approval and operational states', () {
    final approved = StationRecord.fromJson({
      'id': 'station-3',
      'station_type': 'classic',
      'approval_status': ' APPROVED ',
      'operational_status': ' ACTIVE ',
    });
    expect(approved.approvalLabel, 'معتمدة');
    expect(approved.operationalLabel, 'فعالة');

    final rejected = StationRecord.fromJson({
      'id': 'station-4',
      'approval_status': 'rejected',
      'operational_status': 'inactive',
    });
    expect(rejected.approvalLabel, 'مرفوضة');
    expect(rejected.operationalLabel, 'متوقفة');

    final suspended = StationRecord.fromJson({
      'id': 'station-5',
      'approval_status': 'changes_requested',
      'operational_status': 'suspended',
    });
    expect(suspended.approvalLabel, 'تحتاج إلى تعديل');
    expect(suspended.operationalLabel, 'معلّقة');

    final retired = StationRecord.fromJson({
      'id': 'station-6',
      'approval_status': 'pending',
      'operational_status': 'decommissioned',
    });
    expect(retired.approvalLabel, 'بانتظار الاعتماد');
    expect(retired.operationalLabel, 'خارج الخدمة');
  });

  test('uses safe unknown defaults for missing station classification', () {
    final station = StationRecord.fromJson({'id': 'station-2'});
    expect(station.typeLabel, 'نوع غير معروف');
    expect(station.approvalLabel, 'بانتظار الاعتماد');
    expect(station.operationalLabel, 'غير متحقق منها');
  });
}
