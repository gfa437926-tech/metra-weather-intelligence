import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ObservationsPage extends StatefulWidget {
  const ObservationsPage({super.key, required this.client});
  final SupabaseClient? client;

  @override
  State<ObservationsPage> createState() => _ObservationsPageState();
}

class _ObservationsPageState extends State<ObservationsPage> {
  late Future<Map<String, dynamic>> future;
  String? selectedStationId;
  String observationType = 'daily';
  bool busy = false;
  String? _pendingIdempotencyKey;
  String? _pendingRequestFingerprint;
  String? _pendingObservedAt;

  final temperature = TextEditingController();
  final humidity = TextEditingController();
  final windSpeed = TextEditingController();
  final pressure = TextEditingController();
  final precipitation = TextEditingController();
  final description = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = loadData();
  }

  @override
  void dispose() {
    temperature.dispose();
    humidity.dispose();
    windSpeed.dispose();
    pressure.dispose();
    precipitation.dispose();
    description.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> loadData() async {
    final client = widget.client;
    if (client == null) return <String, dynamic>{'own': [], 'review': [], 'stations': []};
    final response = await client.functions.invoke('observations', body: const {'action': 'list'});
    if (response.status != 200 || response.data is! Map) {
      throw Exception(_errorMessage(response.data, 'تعذر تحميل سجل الرصد.'));
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  String _errorMessage(dynamic data, String fallback) {
    if (data is Map && data['error'] != null) {
      const labels = {
        'account_not_active': 'الحساب غير معتمد أو غير نشط.',
        'permission_denied': 'لا تملك الصلاحية المطلوبة.',
        'station_assignment_check_failed': 'تعذر التحقق من تكليف المحطة.',
        'observation_list_failed': 'تعذر تحميل سجل الرصد.',
        'observation_submission_unconfirmed': 'لم يؤكد الخادم حفظ الرصد. أعد المحاولة دون تغيير البيانات.',
      };
      return labels[data['error'].toString()] ?? fallback;
    }
    return fallback;
  }

  double? _readNumber(TextEditingController controller, String label, double min, double max) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < min || parsed > max) {
      throw FormatException('$label يجب أن يكون بين $min و $max.');
    }
    return parsed;
  }

  Future<void> _saveObservation({required bool submit}) async {
    if (busy) return;
    final stationId = selectedStationId;
    if (stationId == null) {
      _toast('اختر محطة رصد أولاً.');
      return;
    }
    Map<String, dynamic> values = {};
    try {
      final t = _readNumber(temperature, 'درجة الحرارة', -90, 65);
      final h = _readNumber(humidity, 'الرطوبة', 0, 100);
      final w = _readNumber(windSpeed, 'سرعة الرياح', 0, 400);
      final p = _readNumber(pressure, 'الضغط الجوي', 800, 1100);
      final rain = _readNumber(precipitation, 'الأمطار', 0, 2000);
      if (t != null) values['temperature_c'] = t;
      if (h != null) values['humidity_percent'] = h;
      if (w != null) values['wind_speed_kmh'] = w;
      if (p != null) values['pressure_hpa'] = p;
      if (rain != null) values['precipitation_mm'] = rain;
      final note = description.text.trim();
      if (note.isNotEmpty) values['description'] = note;
      final hasMeasurement = values.keys.any((key) => key != 'description');
      if (observationType != 'phenomenon' && !hasMeasurement) {
        _toast('أدخل قراءة رقمية واحدة على الأقل.');
        return;
      }
      if (values.isEmpty) {
        _toast('أدخل قراءة واحدة على الأقل أو وصف الظاهرة.');
        return;
      }
      if (observationType == 'phenomenon' && note.isEmpty) {
        _toast('أدخل وصف الظاهرة الجوية.');
        return;
      }
    } on FormatException catch (e) {
      _toast(e.message);
      return;
    }

    final requestFingerprint = jsonEncode({
      'station_id': stationId,
      'observation_type': observationType,
      'payload': values,
      'submit': submit,
    });
    if (_pendingIdempotencyKey == null ||
        _pendingRequestFingerprint != requestFingerprint) {
      final userId = widget.client?.auth.currentUser?.id ?? 'user';
      _pendingIdempotencyKey = '$userId-${DateTime.now().microsecondsSinceEpoch}';
      _pendingRequestFingerprint = requestFingerprint;
      _pendingObservedAt = DateTime.now().toUtc().toIso8601String();
    }
    final idempotencyKey = _pendingIdempotencyKey!;
    final observedAt = _pendingObservedAt!;

    setState(() => busy = true);
    try {
      final response = await widget.client!.functions.invoke('observations', body: {
        'action': 'submit',
        'station_id': stationId,
        'observation_type': observationType,
        'observed_at': observedAt,
        'idempotency_key': idempotencyKey,
        'payload': values,
        'submit': submit,
      });
      if (response.status != 200 || response.data is! Map ||
          response.data['result'] is! Map) {
        throw Exception(_errorMessage(response.data, 'تعذر حفظ الرصد.'));
      }
      final result = Map<String, dynamic>.from(response.data['result'] as Map);
      final expectedStatus = submit ? 'submitted' : 'draft';
      if ((result['id']?.toString().trim().isEmpty ?? true) ||
          result['status'] != expectedStatus ||
          result['replayed'] is! bool) {
        throw Exception('لم يؤكد الخادم حفظ الرصد المطلوب. أعد المحاولة قبل تغيير البيانات.');
      }
      _pendingIdempotencyKey = null;
      _pendingRequestFingerprint = null;
      _pendingObservedAt = null;
      if (!mounted) return;
      _toast(result['replayed'] == true
          ? 'تم التعرف على العملية السابقة دون إنشاء نسخة مكررة.'
          : submit ? 'تم إرسال الرصد للمراجعة.' : 'تم حفظ المسودة.');
      temperature.clear();
      humidity.clear();
      windSpeed.clear();
      pressure.clear();
      precipitation.clear();
      description.clear();
      setState(() => future = loadData());
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _askNote({required bool requiredNote}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(requiredNote ? 'سبب إعادة الرصد للتصحيح' : 'ملاحظة المراجع (اختياري)'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'اكتب الملاحظة...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (requiredNote && text.isEmpty) return;
                Navigator.pop(dialogContext, text);
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _decide(Map<String, dynamic> item, String decision) async {
    final note = await _askNote(requiredNote: decision == 'return_for_correction');
    if (note == null) return;
    setState(() => busy = true);
    try {
      final response = await widget.client!.functions.invoke('observations', body: {
        'action': 'decide',
        'station_id': item['station_id'],
        'observation_id': item['id'],
        'decision': decision,
        'note': note,
      });
      if (response.status != 200 || response.data is! Map || response.data['result'] is! Map) {
        throw Exception(_errorMessage(response.data, 'تعذر تنفيذ قرار المراجعة.'));
      }
      final result = Map<String, dynamic>.from(response.data['result'] as Map);
      final expectedStatus = decision == 'approve' ? 'approved' : 'returned';
      if (result['id'] != item['id'] || result['status'] != expectedStatus) {
        throw Exception('لم يؤكد الخادم حفظ قرار المراجعة المطلوب. حدّث السجل قبل المتابعة.');
      }
      if (!mounted) return;
      _toast(decision == 'approve' ? 'تم اعتماد الرصد.' : 'أعيد الرصد للتصحيح.');
      setState(() => future = loadData());
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _status(String? status) => switch (status) {
    'draft' => 'مسودة',
    'submitted' => 'بانتظار المراجعة',
    'approved' => 'معتمد',
    'returned' => 'معاد للتصحيح',
    _ => 'غير معروف',
  };

  String _type(String? type) => switch (type) {
    'daily' => 'رصد يومي',
    'hourly' => 'رصد ساعي',
    'phenomenon' => 'ظاهرة جوية',
    _ => 'رصد',
  };

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 18),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF102448)))),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
    ]),
  );

  Widget _observationCard(Map<String, dynamic> item, {bool review = false}) {
    final station = item['station'] is Map ? Map<String, dynamic>.from(item['station'] as Map) : <String, dynamic>{};
    final payload = item['payload'] is Map ? Map<String, dynamic>.from(item['payload'] as Map) : <String, dynamic>{};
    final canApprove = item['can_approve'] == true;
    final canReturn = item['can_return'] == true;
    final observedAt = DateTime.tryParse(item['observed_at']?.toString() ?? '')?.toLocal();
    final values = <String>[
      if (payload['temperature_c'] != null) 'الحرارة ${payload['temperature_c']}°',
      if (payload['humidity_percent'] != null) 'الرطوبة ${payload['humidity_percent']}%',
      if (payload['wind_speed_kmh'] != null) 'الرياح ${payload['wind_speed_kmh']} كم/س',
      if (payload['pressure_hpa'] != null) 'الضغط ${payload['pressure_hpa']} hPa',
      if (payload['precipitation_mm'] != null) 'الأمطار ${payload['precipitation_mm']} مم',
    ];
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5EAF2))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sensors, color: Color(0xFF1769D2)),
            const SizedBox(width: 8),
            Expanded(child: Text(station['name']?.toString() ?? 'محطة', style: const TextStyle(fontWeight: FontWeight.bold))),
            Chip(label: Text(_status(item['status']?.toString()), style: const TextStyle(fontSize: 10))),
          ]),
          Text(_type(item['observation_type']?.toString()), style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          if (observedAt != null) Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('وقت الرصد: ${observedAt.year}-${observedAt.month.toString().padLeft(2, '0')}-${observedAt.day.toString().padLeft(2, '0')} ${observedAt.hour.toString().padLeft(2, '0')}:${observedAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
          ),
          if (values.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 6, children: values.map((v) => Chip(label: Text(v, style: const TextStyle(fontSize: 11)))).toList()),
          ),
          if (payload['description'] != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(payload['description'].toString(), style: const TextStyle(fontSize: 12)),
          ),
          if (item['review_note'] != null && item['review_note'].toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('ملاحظة: ${item['review_note']}', style: const TextStyle(color: Colors.deepOrange, fontSize: 12))),
          if (review && (canApprove || canReturn)) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              if (canApprove) FilledButton.icon(
                onPressed: busy ? null : () => _decide(item, 'approve'),
                icon: const Icon(Icons.verified_outlined, size: 17),
                label: const Text('اعتماد'),
              ),
              if (canReturn) OutlinedButton.icon(
                onPressed: busy ? null : () => _decide(item, 'return_for_correction'),
                icon: const Icon(Icons.assignment_return_outlined, size: 17),
                label: const Text('إعادة للتصحيح'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, String suffix) => SizedBox(
    width: 150,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder(), isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.client == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الرصد التشغيلي')),
          body: const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('خدمة الرصد غير مهيأة. شغّل التطبيق بإعدادات Supabase.'),
          )),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرصد التشغيلي'),
          actions: [IconButton(
            tooltip: 'تحديث',
            onPressed: busy ? null : () => setState(() => future = loadData()),
            icon: const Icon(Icons.refresh),
          )],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, color: Colors.blueGrey, size: 36),
                const SizedBox(height: 10),
                Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                TextButton(onPressed: () => setState(() => future = loadData()), child: const Text('إعادة المحاولة')),
              ]),
            ));
            final data = snapshot.data ?? <String, dynamic>{};
            final stations = (data['stations'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            final own = (data['own'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            final review = (data['review'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            selectedStationId ??= stations.isNotEmpty ? stations.first['id']?.toString() : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(16)),
                  child: const Text('أدخل قراءات المحطة ثم احفظها كمسودة أو أرسلها للمراجعة. لا تُعتمد القراءات إلا بقرار مراجع مخوّل.', style: TextStyle(fontSize: 12, color: Color(0xFF234A7C))),
                ),
                if (stations.isNotEmpty) ...[
                  _sectionTitle('إدخال رصد جديد', 'قراءات موثقة'),
                  DropdownButtonFormField<String>(
                    value: selectedStationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'محطة الرصد', border: OutlineInputBorder()),
                    items: stations.map((s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text('${s['name_ar'] ?? 'محطة'} • ${s['local_station_code'] ?? ''}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: busy ? null : (value) => setState(() => selectedStationId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: observationType,
                    decoration: const InputDecoration(labelText: 'نوع الرصد', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('رصد يومي')),
                      DropdownMenuItem(value: 'hourly', child: Text('رصد ساعي')),
                      DropdownMenuItem(value: 'phenomenon', child: Text('ظاهرة جوية')),
                    ],
                    onChanged: busy ? null : (value) => setState(() => observationType = value ?? 'daily'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _numberField(temperature, 'درجة الحرارة', '°C'),
                    _numberField(humidity, 'الرطوبة', '%'),
                    _numberField(windSpeed, 'سرعة الرياح', 'كم/س'),
                    _numberField(pressure, 'الضغط', 'hPa'),
                    _numberField(precipitation, 'الأمطار', 'مم'),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'الوصف / ملاحظات الرصد', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _saveObservation(submit: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ مسودة'),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _saveObservation(submit: true),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('إرسال للمراجعة'),
                    ),
                    if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('لا توجد محطة معتمدة ونشطة ومكلف بها حسابك لإدخال الرصد.', style: TextStyle(color: Colors.blueGrey)),
                  ),
                _sectionTitle('طلبات المراجعة', '${review.length}'),
                if (review.isEmpty) const Text('لا توجد قراءات بانتظار المراجعة ضمن صلاحياتك.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ...review.map((item) => _observationCard(item, review: true)),
                _sectionTitle('سجل رصدك', '${own.length}'),
                if (own.isEmpty) const Text('لم تسجل أي قراءات بعد.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ...own.map((item) => _observationCard(item)),
              ],
            );
          },
        ),
      ),
    );
  }
}
