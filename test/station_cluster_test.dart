import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/station_cluster.dart';
import 'package:metra_weather_intelligence/domain/station_record.dart';

StationRecord station({
  required String id,
  required String type,
  Object? latitude = 24.7136,
  Object? longitude = 46.6753,
}) => StationRecord.fromJson({
  'id': id,
  'local_station_code': id,
  'name_ar': id,
  'station_type': type,
  'latitude': latitude,
  'longitude': longitude,
});

void main() {
  test('keeps classic, automatic and unknown stations at the same point', () {
    final clusters = clusterStationsByCoordinates([
      station(id: 'classic-1', type: 'classic'),
      station(id: 'auto-1', type: 'automatic'),
      station(id: 'unknown-1', type: 'legacy'),
    ]);
    expect(clusters, hasLength(1));
    expect(clusters.values.single.map((item) => item.id),
        ['classic-1', 'auto-1', 'unknown-1']);
  });

  test('does not merge distinct coordinates', () {
    final clusters = clusterStationsByCoordinates([
      station(id: 'one', type: 'classic'),
      station(id: 'two', type: 'automatic', latitude: 25.0, longitude: 46.0),
    ]);
    expect(clusters, hasLength(2));
  });

  test('excludes invalid coordinates from map clusters only', () {
    final located = station(id: 'located', type: 'classic');
    final unlocated = station(id: 'unlocated', type: 'automatic', latitude: null);
    final clusters = clusterStationsByCoordinates([located, unlocated]);
    expect(clusters.values.expand((items) => items).map((item) => item.id),
        ['located']);
  });

  test('returns immutable clusters to protect grouped station records', () {
    final clusters = clusterStationsByCoordinates([
      station(id: 'one', type: 'classic'),
    ]);
    expect(() => clusters.clear(), throwsUnsupportedError);
    expect(() => clusters.values.single.clear(), throwsUnsupportedError);
  });
}
