import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/weather_snapshot.dart';

class WeatherService {
 WeatherService({http.Client? client}):_client=client??http.Client();
 final http.Client _client;
 Future<WeatherSnapshot> fetchRiyadh() async {
  final uri=Uri.https('api.open-meteo.com','/v1/forecast',{
   'latitude':'24.7136','longitude':'46.6753',
   'current':'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure',
   'daily':'temperature_2m_max,temperature_2m_min',
   'timezone':'Asia/Riyadh','forecast_days':'1'
  });
  final response=await _client.get(uri).timeout(const Duration(seconds:12));
  if(response.statusCode!=200) throw WeatherServiceException('Weather provider returned ${response.statusCode}');
  final decoded=jsonDecode(response.body);
  if(decoded is! Map<String,dynamic>) throw const WeatherServiceException('Invalid weather response');
  try { return WeatherSnapshot.fromJson(decoded); }
  on Object { throw const WeatherServiceException('Invalid weather payload'); }
 }
}
class WeatherServiceException implements Exception {
 const WeatherServiceException(this.message);
 final String message;
 @override String toString()=>message;
}
