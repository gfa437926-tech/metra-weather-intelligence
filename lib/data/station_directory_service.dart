import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/station_record.dart';

class StationDirectoryService {
  StationDirectoryService(this._client);
  final SupabaseClient _client;

  Future<List<StationRecord>> fetchStations() async {
    final response = await _client.functions.invoke('station-directory');
    if (response.status != 200 || response.data is! Map) {
      throw const StationDirectoryException('تعذر تحميل دليل المحطات من الخدمة الآمنة.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = data['stations'];
    if (rows is! List) throw const StationDirectoryException('استجابة دليل المحطات غير صالحة.');
    return rows.whereType<Map>()
        .map((row) => StationRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

class StationDirectoryException implements Exception {
  const StationDirectoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
