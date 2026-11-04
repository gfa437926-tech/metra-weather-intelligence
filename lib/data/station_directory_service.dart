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
    return parseStationRows(data['stations']);
  }

  Future<AccessContext> fetchAccessContext() async =>
      AccessContext.fromJson(await _fetchPayload());
}

List<StationRecord> parseStationRows(Object? value) {
  if (value is! List) {
    throw const StationDirectoryException('استجابة دليل المحطات غير صالحة.');
  }
  final stations = <StationRecord>[];
  for (var index = 0; index < value.length; index++) {
    final row = value[index];
    if (row is! Map) {
      throw StationDirectoryException('سجل المحطة رقم ${index + 1} غير صالح.');
    }
    final json = Map<String, dynamic>.from(row);
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StationDirectoryException('سجل المحطة رقم ${index + 1} لا يحتوي على معرّف.');
    }
    stations.add(StationRecord.fromJson(json));
  }
  return List<StationRecord>.unmodifiable(stations);
}

class StationDirectoryException implements Exception {
  const StationDirectoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
