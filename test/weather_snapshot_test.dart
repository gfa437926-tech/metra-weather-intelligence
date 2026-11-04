import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/weather_snapshot.dart';

void main() {
 test('parses current and daily Open-Meteo values', () {
  final snapshot=WeatherSnapshot.fromJson({
   'current': {
    'temperature_2m': 31.4,
    'apparent_temperature': 33.2,
    'relative_humidity_2m': 42,
    'wind_speed_10m': 14.5,
    'surface_pressure': 1008.7,
    'weather_code': 2,
   },
   'daily': {
    'temperature_2m_max': [35.0],
    'temperature_2m_min': [22.0],
   },
  });
  expect(snapshot.temperature,31.4);
  expect(snapshot.humidity,42);
  expect(snapshot.maxTemperature,35);
  expect(snapshot.minTemperature,22);
  expect(snapshot.condition,'غائم جزئياً');
 });
 test('maps thunderstorm weather codes to a clear Arabic label', () {
  final snapshot=WeatherSnapshot.fromJson({
   'current': {'temperature_2m':1,'apparent_temperature':1,'relative_humidity_2m':1,'wind_speed_10m':1,'surface_pressure':1,'weather_code':95},
   'daily': {'temperature_2m_max':[2],'temperature_2m_min':[0]},
  });
  expect(snapshot.condition,'عواصف رعدية');
 });
 test('rejects missing or empty daily temperature arrays', () {
  expect(
   () => WeatherSnapshot.fromJson({
    'current': {'temperature_2m': 1, 'apparent_temperature': 1, 'relative_humidity_2m': 1, 'wind_speed_10m': 1, 'surface_pressure': 1, 'weather_code': 0},
    'daily': {'temperature_2m_max': [], 'temperature_2m_min': [0]},
   }),
   throwsFormatException,
  );
 });
 test('rejects non-finite provider measurements', () {
  expect(
   () => WeatherSnapshot.fromJson({
    'current': {'temperature_2m': double.nan, 'apparent_temperature': 1, 'relative_humidity_2m': 1, 'wind_speed_10m': 1, 'surface_pressure': 1, 'weather_code': 0},
    'daily': {'temperature_2m_max': [2], 'temperature_2m_min': [0]},
   }),
   throwsFormatException,
  );
 });

 test('rejects physically invalid humidity, wind and pressure values', () {
  Map<String, dynamic> payload({
   num humidity = 40,
   num wind = 2,
   num pressure = 1000,
  }) => {
   'current': {'temperature_2m': 1, 'apparent_temperature': 1, 'relative_humidity_2m': humidity, 'wind_speed_10m': wind, 'surface_pressure': pressure, 'weather_code': 0},
   'daily': {'temperature_2m_max': [2], 'temperature_2m_min': [0]},
  };
  expect(() => WeatherSnapshot.fromJson(payload(humidity: 101)), throwsFormatException);
  expect(() => WeatherSnapshot.fromJson(payload(humidity: -1)), throwsFormatException);
  expect(() => WeatherSnapshot.fromJson(payload(wind: -0.1)), throwsFormatException);
  expect(() => WeatherSnapshot.fromJson(payload(pressure: 0)), throwsFormatException);
 });
 test('rejects weather codes outside the WMO code range', () {
  expect(
   () => WeatherSnapshot.fromJson({
    'current': {'temperature_2m': 1, 'apparent_temperature': 1, 'relative_humidity_2m': 40, 'wind_speed_10m': 1, 'surface_pressure': 1000, 'weather_code': 100},
    'daily': {'temperature_2m_max': [2], 'temperature_2m_min': [0]},
   }),
   throwsFormatException,
  );
 });

}
