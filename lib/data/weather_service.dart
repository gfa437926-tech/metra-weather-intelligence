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
   'hourly':'temperature_2m,weather_code',
   'forecast_hours':'24',
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
Future<List<HourlyForecast>> fetchHourlyRiyadh() async {
  final uri=Uri.https('api.open-meteo.com','/v1/forecast',{
   'latitude':'24.7136','longitude':'46.6753','hourly':'temperature_2m,weather_code',
   'forecast_hours':'24','timezone':'Asia/Riyadh'
  });
  final response=await _client.get(uri).timeout(const Duration(seconds:12));
  if(response.statusCode!=200) throw WeatherServiceException('Weather provider returned ${response.statusCode}');
  final decoded=jsonDecode(response.body);
  if(decoded is! Map<String,dynamic>) throw const WeatherServiceException('Invalid forecast response');
  final hourly=decoded['hourly'];
  if(hourly is! Map) throw const WeatherServiceException('Missing hourly forecast');
  final times=hourly['time'], temps=hourly['temperature_2m'], codes=hourly['weather_code'];
  if(times is! List || temps is! List || codes is! List || times.length!=temps.length || times.length!=codes.length) throw const WeatherServiceException('Invalid hourly forecast');
  return List.generate(times.length,(i)=>HourlyForecast(time:DateTime.parse(times[i] as String),temperature:(temps[i] as num).toDouble(),weatherCode:(codes[i] as num).toInt()));
 }
}
class HourlyForecast {
 const HourlyForecast({required this.time,required this.temperature,required this.weatherCode});
 final DateTime time; final double temperature; final int weatherCode;
 String get symbol => weatherCode==0?'☀':weatherCode<=3?'⛅':weatherCode>=95?'⛈':weatherCode>=51?'🌧':'☁';
 String get label => '${time.hour.toString().padLeft(2,'0')}:00';
}
class WeatherServiceException implements Exception {
 const WeatherServiceException(this.message);
 final String message;
 @override String toString()=>message;
}
