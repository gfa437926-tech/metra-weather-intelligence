class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.maxTemperature,
    required this.minTemperature,
    required this.weatherCode,
  });

  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double windSpeed;
  final double pressure;
  final double maxTemperature;
  final double minTemperature;
  final int weatherCode;

  String get condition {
    if (weatherCode == 0) return 'سماء صافية';
    if (weatherCode <= 3) return 'غائم جزئياً';
    if (weatherCode == 45 || weatherCode == 48) return 'ضباب';
    if (weatherCode >= 51 && weatherCode <= 67) return 'رذاذ أو أمطار';
    if (weatherCode >= 71 && weatherCode <= 77) return 'تساقط ثلجي';
    if (weatherCode >= 80 && weatherCode <= 82) return 'زخات مطرية';
    if (weatherCode >= 95) return 'عواصف رعدية';
    return 'حالة جوية متغيرة';
  }

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final daily = json['daily'];
    if (current is! Map || daily is! Map) {
      throw const FormatException('Missing current or daily weather data');
    }

    double number(Map data, String key) {
      final value = data[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid numeric weather field: $key');
      }
      return value.toDouble();
    }

    final maxValues = daily['temperature_2m_max'];
    final minValues = daily['temperature_2m_min'];
    if (maxValues is! List || maxValues.isEmpty ||
        minValues is! List || minValues.isEmpty) {
      throw const FormatException('Missing daily temperature values');
    }

    final humidity = number(current, 'relative_humidity_2m');
    final windSpeed = number(current, 'wind_speed_10m');
    final pressure = number(current, 'surface_pressure');
    if (humidity < 0 || humidity > 100) {
      throw const FormatException('Relative humidity must be between 0 and 100');
    }
    if (windSpeed < 0) {
      throw const FormatException('Wind speed cannot be negative');
    }
    if (pressure <= 0) {
      throw const FormatException('Surface pressure must be positive');
    }

    final code = current['weather_code'];
    if (code is! num || !code.isFinite || code % 1 != 0 || code < 0 || code > 99) {
      throw const FormatException('Invalid weather code');
    }

    return WeatherSnapshot(
      temperature: number(current, 'temperature_2m'),
      apparentTemperature: number(current, 'apparent_temperature'),
      humidity: humidity,
      windSpeed: windSpeed,
      pressure: pressure,
      maxTemperature: _listNumber(maxValues.first, 'temperature_2m_max'),
      minTemperature: _listNumber(minValues.first, 'temperature_2m_min'),
      weatherCode: code.toInt(),
    );
  }

  static double _listNumber(dynamic value, String key) {
    if (value is! num || !value.isFinite) {
      throw FormatException('Invalid daily weather field: $key');
    }
    return value.toDouble();
  }
}
