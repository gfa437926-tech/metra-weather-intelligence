class WeatherSnapshot {
 const WeatherSnapshot({required this.temperature,required this.apparentTemperature,required this.humidity,required this.windSpeed,required this.pressure,required this.maxTemperature,required this.minTemperature,required this.weatherCode});
 final double temperature,apparentTemperature,humidity,windSpeed,pressure,maxTemperature,minTemperature;
 final int weatherCode;
 String get condition {
  if(weatherCode==0)return 'سماء صافية';
  if(weatherCode<=3)return 'غائم جزئياً';
  if(weatherCode==45||weatherCode==48)return 'ضباب';
  if(weatherCode>=51&&weatherCode<=67)return 'رذاذ أو أمطار';
  if(weatherCode>=71&&weatherCode<=77)return 'تساقط ثلجي';
  if(weatherCode>=80&&weatherCode<=82)return 'زخات مطرية';
  if(weatherCode>=95)return 'عواصف رعدية';
  return 'حالة جوية متغيرة';
 }
 factory WeatherSnapshot.fromJson(Map<String,dynamic> json) {
  final current=Map<String,dynamic>.from(json['current'] as Map);
  final daily=Map<String,dynamic>.from(json['daily'] as Map);
  double number(dynamic value)=> (value as num).toDouble();
  int integer(dynamic value)=>(value as num).toInt();
  return WeatherSnapshot(
   temperature:number(current['temperature_2m']),
   apparentTemperature:number(current['apparent_temperature']),
   humidity:number(current['relative_humidity_2m']),
   windSpeed:number(current['wind_speed_10m']),
   pressure:number(current['surface_pressure']),
   maxTemperature:number((daily['temperature_2m_max'] as List).first),
   minTemperature:number((daily['temperature_2m_min'] as List).first),
   weatherCode:integer(current['weather_code']),
  );
 }
}
