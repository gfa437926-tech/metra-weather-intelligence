import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/access_context.dart';
import '../domain/station_record.dart';

class StationDirectoryService {
  StationDirectoryService(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> _fetchPayload() async {
    final response = await _client.functions.invoke('station-directory');
    if (response.status != 200 || response.data is! Map) {
      throw const StationDirectoryException('تعذر تحميل بيانات الحساب ودليل المحطات من الخدمة الآمنة.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<StationRecord>> fetchStations() async {
    final data = await _fetchPayload();
    final rows = data['stations'];
    if (rows is! List) throw const StationDirectoryException('استجابة دليل المحطات غير صالحة.');
    return rows.whereType<Map>()
        .map((row) => StationRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<AccessContext> fetchAccessContext() async =>
      AccessContext.fromJson(await _fetchPayload());
}

class StationDirectoryException implements Exception {
  const StationDirectoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
