enum StationType { classic, automatic }

class WeatherStation {
  const WeatherStation({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.elevationMeters,
  });

  final String id;
  final String name;
  final StationType type;
  final double latitude;
  final double longitude;
  final double? elevationMeters;

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  String get typeLabel =>
      type == StationType.classic ? 'كلاسيكية' : 'آلية';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherStation &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.elevationMeters == elevationMeters;

  @override
  int get hashCode =>
      Object.hash(id, name, type, latitude, longitude, elevationMeters);
}
