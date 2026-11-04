import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/weather_snapshot.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? _sharedClient;

  // Reuse the default connection pool across dashboard widgets. Tests can
  // inject their own client without sharing or closing the application client.
  static final http.Client _sharedClient = http.Client();
  final http.Client _client;

  Future<WeatherSnapshot> fetchDamascus() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '33.5138',
      'longitude': '36.2765',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'timezone': 'Asia/Damascus',
      'forecast_days': '1',
    });
    final response = await _get(uri);
    final decoded = _decodeObject(response.body, 'Invalid weather response');
    try {
      return WeatherSnapshot.fromJson(decoded);
    } on Object {
      throw const WeatherServiceException('Invalid weather payload');
    }
  }

  Future<List<HourlyForecast>> fetchHourlyDamascus() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '33.5138',
      'longitude': '36.2765',
      'hourly': 'temperature_2m,weather_code',
      'forecast_hours': '24',
      'timezone': 'Asia/Damascus',
    });
    final response = await _get(uri);
    final decoded = _decodeObject(response.body, 'Invalid forecast response');
    final hourly = decoded['hourly'];
    if (hourly is! Map) {
      throw const WeatherServiceException('Missing hourly forecast');
    }
    final times = hourly['time'];
    final temps = hourly['temperature_2m'];
    final codes = hourly['weather_code'];
    if (times is! List ||
        temps is! List ||
        codes is! List ||
        times.isEmpty ||
        times.length != temps.length ||
        times.length != codes.length) {
      throw const WeatherServiceException('Invalid hourly forecast');
    }
    try {
      return List.generate(times.length, (i) {
        final rawTime = times[i];
        final rawTemperature = temps[i];
        final rawCode = codes[i];
        if (rawTime is! String ||
            rawTemperature is! num ||
            !rawTemperature.isFinite ||
            rawCode is! num ||
            !rawCode.isFinite ||
            rawCode % 1 != 0 ||
            rawCode < 0 ||
            rawCode > 99) {
          throw const FormatException('Invalid hourly forecast value');
        }
        return HourlyForecast(
          time: DateTime.parse(rawTime),
          temperature: rawTemperature.toDouble(),
          weatherCode: rawCode.toInt(),
        );
      });
    } on Object {
      throw const WeatherServiceException('Invalid hourly forecast values');
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw WeatherServiceException(
          'Weather provider returned ${response.statusCode}',
        );
      }
      return response;
    } on WeatherServiceException {
      rethrow;
    } on Object {
      throw const WeatherServiceException('Weather provider is unavailable');
    }
  }

  Map<String, dynamic> _decodeObject(String body, String message) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Object {
      // Convert provider/parser failures to a stable domain-level exception.
    }
    throw WeatherServiceException(message);
  }
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;

  String get symbol => weatherCode == 0
      ? '☀'
      : weatherCode <= 3
          ? '⛅'
          : weatherCode >= 95
              ? '⛈'
              : weatherCode >= 51
                  ? '🌧'
                  : '☁';

  String get label => '${time.hour.toString().padLeft(2, '0')}:00';
}

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
