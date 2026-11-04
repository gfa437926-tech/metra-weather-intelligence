import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StationReviewPage extends StatefulWidget {
  const StationReviewPage({super.key, required this.client});
  final SupabaseClient? client;
  @override
  State<StationReviewPage> createState() => _StationReviewPageState();
}

class _StationReviewPageState extends State<StationReviewPage> {
  late Future<List<Map<String, dynamic>>> queue;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    queue = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = widget.client;
    if (client == null) return [];
    final response = await client.functions.invoke('station-review', body: const {'action': 'list'});
    if (response.status != 200 || response.data is! Map) {
      throw Exception(_message(response.data));
    }
    final rows = (response.data as Map)['stations'];
    if (rows is! List) throw Exception('استجابة قائمة المحطات غير صالحة.');
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  String _message(dynamic data) {
    final code = data is Map ? data['error']?.toString() : null;
    const messages = {
      'account_not_active': 'الحساب غير معتمد أو غير نشط.',
      'permission_denied': 'لا تملك صلاحية مراجعة دليل المحطات.',
      'station_review_queue_failed': 'تعذر تحميل قائمة المحطات.',
      'station_coordinate_lookup_failed': 'تعذر تحميل إحداثيات المحطات.',
    };
    return messages[code] ?? 'تعذر تنفيذ الطلب. حاول مرة أخرى.';
  }

  Future<void> _decide(Map<String, dynamic> station, String decision) async {
    final controller = TextEditingController();
    final title = switch (decision) {
      'approved' => 'اعتماد بيانات المحطة',
      'rejected' => 'رفض بيانات المحطة',
      _ => 'طلب استكمال بيانات المحطة',
    };
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'سبب القرار (5 أحرف على الأقل)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length < 5) return;
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('تأكيد القرار'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reason == null || !mounted || busy) return;
    setState(() => busy = true);
    try {
      final response = await widget.client!.functions.invoke('station-review', body: {
        'action': 'decide',
        'station_id': station['id'],
        'decision': decision,
        'reason': reason,
      });
      if (response.status != 200 || response.data is! Map) {
        throw Exception(_message(response.data));
      }
      final result = (response.data as Map)['result'];
      if (result is! Map) {
        throw Exception('لم يرجع الخادم نتيجة مؤكدة لقرار المراجعة. حدّث القائمة قبل المتابعة.');
      }
      if (result['result_status'] == 'state_conflict') {
        throw Exception('تغيرت حالة المحطة بواسطة مراجع آخر. حدّث القائمة.');
      }
      if (result['result_status'] != 'updated' ||
          result['resulting_status'] != decision) {
        throw Exception('لم يؤكد الخادم حفظ القرار المطلوب. حدّث القائمة قبل المتابعة.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل القرار وسجل التدقيق.')));
      setState(() => queue = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراجعة واعتماد المحطات'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: busy ? null : () => setState(() => queue = _load()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: widget.client == null
            ? const Center(child: Text('يلزم إعداد اتصال Supabase لتشغيل مراجعة المحطات.'))
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: queue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 42),
                            const SizedBox(height: 12),
                            Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: () => setState(() => queue = _load()), child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      ),
                    );
                  }
                  final stations = snapshot.data ?? [];
                  if (stations.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد محطات بانتظار المراجعة أو لا توجد صلاحية لعرض القائمة.', textAlign: TextAlign.center),
                    ));
                  }
                  return Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: stations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          final coordinate = station['current_coordinate'];
                          final hasCoordinate = coordinate is Map;
                          final name = (station['name_ar'] ?? station['name_en'] ?? 'محطة').toString();
                          final code = (station['local_station_code'] ?? '').toString();
                          final type = station['station_type'] == 'classic' ? 'كلاسيكية' : 'آلية';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.sensors, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                                    Chip(label: Text(type)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text('رمز المحطة: $code'),
                                  Text(hasCoordinate
                                      ? 'الإحداثيات: ${coordinate['latitude']}, ${coordinate['longitude']}'
                                      : 'الإحداثيات الحالية: غير متوفرة'),
                                  Text('حالة التشغيل: ${station['operational_status'] ?? 'غير متحقق منها'}'),
                                  if (station['source_system'] != null)
                                    Text('مصدر السجل: ${station['source_system']} / ${station['source_table'] ?? ''} / ${station['source_record_id'] ?? ''}'),
                                  if (!hasCoordinate)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('تنبيه: لا تعتمد الإحداثيات التشغيلية قبل استكمال التحقق المكاني.', style: TextStyle(color: Colors.deepOrange)),
                                    ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: busy ? null : () => _decide(station, 'approved'),
                                        icon: const Icon(Icons.verified_outlined),
                                        label: const Text('اعتماد البيانات'),
                                      ),
                                      OutlinedButton(
                                        onPressed: busy ? null : () => _decide(station, 'changes_requested'),
                                        child: const Text('طلب استكمال'),
                                      ),
                                      TextButton(
                                        onPressed: busy ? null : () => _decide(station, 'rejected'),
                                        child: const Text('رفض'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
