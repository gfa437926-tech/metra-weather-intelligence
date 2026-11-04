import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/data/station_directory_service.dart';

void main() {
  Map<String, dynamic> station({String id = 'station-1'}) => {
    'id': id,
    'local_station_code': 'RYD-001',
    'name_ar': 'محطة الرياض',
    'station_type': 'automatic',
    'approval_status': 'approved',
    'operational_status': 'active',
  };

  test('parses every valid station row without dropping records', () {
    final rows = parseStationRows([station(), station(id: 'station-2')]);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.id), ['station-1', 'station-2']);
    expect(() => rows.add(rows.first), throwsUnsupportedError);
  });

  test('rejects a malformed station collection', () {
    expect(() => parseStationRows(null), throwsA(isA<StationDirectoryException>()));
    expect(() => parseStationRows({'id': 'station-1'}), throwsA(isA<StationDirectoryException>()));
  });

  test('does not silently discard a malformed row among valid stations', () {
    expect(
      () => parseStationRows([station(), 'corrupt-row', station(id: 'station-3')]),
      throwsA(isA<StationDirectoryException>()),
    );
  });

  test('rejects station rows without an identifier', () {
    expect(
      () => parseStationRows([station(id: '  ')]),
      throwsA(isA<StationDirectoryException>()),
    );
  });
}
