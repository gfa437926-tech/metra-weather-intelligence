import 'station_record.dart';

/// Groups co-located stations without dropping any station record.
Map<String, List<StationRecord>> clusterStationsByCoordinates(
  Iterable<StationRecord> stations,
) {
  final clusters = <String, List<StationRecord>>{};
  for (final station in stations) {
    if (!station.hasCoordinates) continue;
    final key =
        '${station.latitude!.toStringAsFixed(5)},${station.longitude!.toStringAsFixed(5)}';
    clusters.putIfAbsent(key, () => <StationRecord>[]).add(station);
  }
  return Map.unmodifiable({
    for (final entry in clusters.entries)
      entry.key: List<StationRecord>.unmodifiable(entry.value),
  });
}
