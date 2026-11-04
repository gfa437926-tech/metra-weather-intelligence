import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationGate extends StatefulWidget {
  const RegistrationGate({super.key, required this.homeBuilder});
  final WidgetBuilder homeBuilder;
  @override
  State<RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<RegistrationGate> {
  late Future<Map<String, dynamic>> status;

  @override
  void initState() {
    super.initState();
    status = loadStatus();
  }

  Future<Map<String, dynamic>> loadStatus() async {
    final response = await Supabase.instance.client.functions.invoke(
      'registration', body: const {'action': 'status'},
    );
    if (response.status != 200 || response.data is! Map) {
      throw Exception('تعذر التحقق من حالة الحساب.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  void refresh() => setState(() => status = loadStatus());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: status,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _MessagePage(title: 'التحقق من الحساب', message: 'جارٍ التحقق من حالة الاعتماد...', loading: true);
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _MessagePage(
          title: 'تعذر التحقق من الحساب',
          message: 'لن يتم فتح بيانات النظام قبل اكتمال التحقق من حالة الحساب.',
          action: 'إعادة المحاولة', onAction: refresh,
        );
      }
      final state = snapshot.data!['account_state']?.toString() ?? 'needs_registration';
      if (state == 'active') return widget.homeBuilder(context);
      if (state == 'needs_registration') return RegistrationPage(onSubmitted: refresh);
      if (state == 'pending' || state == 'pending_station_approval' || state == 'pending_system_approval') {
        return _MessagePage(
          title: 'طلب الانتساب قيد المراجعة',
          message: 'تم استلام طلبك. ستتاح وظائف METRA بعد اعتماد الحساب والعضوية والصلاحيات.',
          action: 'تحديث الحالة', onAction: refresh,
          secondary: 'تسجيل الخروج',
          onSecondary: () => Supabase.instance.client.auth.signOut(),
        );
      }
      return _MessagePage(
        title: 'الحساب غير مفعّل',
        message: (snapshot.data!['state_reason'] ?? 'يرجى التواصل مع مسؤول النظام.').toString(),
        action: 'تسجيل الخروج',
        onAction: () => Supabase.instance.client.auth.signOut(),
      );
    },
  );
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!email.text.trim().contains('@') || password.text.length < 8) {
      setState(() => error = 'أدخل بريداً صحيحاً وكلمة مرور من 8 محارف على الأقل.');
      return;
    }
    setState(() { busy = true; error = null; message = null; });
    try {
      final result = await Supabase.instance.client.auth.signUp(
        email: email.text.trim(), password: password.text,
      );
      setState(() => message = result.session == null
        ? 'تم إنشاء الحساب. تحقق من بريدك ثم سجّل الدخول لإكمال طلب الانتساب.'
        : 'تم إنشاء الحساب. أكمل نموذج طلب الانتساب.');
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'تعذر إنشاء الحساب حالياً.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب METRA')),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.person_add_alt_1, size: 54, color: Color(0xFF071A43)),
            const SizedBox(height: 16),
            const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('إنشاء الحساب لا يمنح صلاحية الدخول تلقائياً. يجب تقديم طلب انتساب وانتظار الاعتماد.'),
            const SizedBox(height: 20),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور (8 محارف على الأقل)', border: OutlineInputBorder())),
            if (error != null) _InlineNotice(error!, true),
            if (message != null) _InlineNotice(message!, false),
            if (message != null) TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('متابعة'),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: busy ? null : submit,
              child: busy ? const CircularProgressIndicator() : const Text('إنشاء الحساب'),
            )),
          ]),
        ),
      )),
    ),
  );
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.onSubmitted});
  final VoidCallback onSubmitted;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final first = TextEditingController();
  final father = TextEditingController();
  final last = TextEditingController();
  final phone = TextEditingController();
  late final String idempotencyKey;
  late Future<Map<String, dynamic>> catalog;
  String? role;
  String? station;
  bool terms = false;
  bool busy = false;
  String? error;
  String? success;

  @override
  void initState() {
    super.initState();
    idempotencyKey = (Supabase.instance.client.auth.currentUser?.id ?? 'user') +
      '-' + DateTime.now().microsecondsSinceEpoch.toString();
    catalog = loadCatalog();
  }

  @override
  void dispose() {
    first.dispose(); father.dispose(); last.dispose(); phone.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> loadCatalog() async {
    final response = await Supabase.instance.client.functions.invoke(
      'registration', body: const {'action': 'catalog'},
    );
    if (response.status != 200 || response.data is! Map) {
      throw Exception('تعذر تحميل قائمة الأدوار والمحطات.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> submit() async {
    if (first.text.trim().isEmpty || father.text.trim().isEmpty ||
        last.text.trim().isEmpty || role == null || station == null || !terms) {
      setState(() => error = 'أكمل الحقول المطلوبة واختر الدور والمحطة ووافق على الشروط.');
      return;
    }
    setState(() { busy = true; error = null; success = null; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'registration',
        body: {
          'action': 'submit',
          'first_name': first.text.trim(),
          'father_name': father.text.trim(),
          'last_name': last.text.trim(),
          'phone': phone.text.trim(),
          'role_code': role,
          'station_id': station,
          'terms_version': 'metra-terms-2026-11',
          'idempotency_key': idempotencyKey,
        },
      );
      if (response.status != 200 || response.data is! Map) {
        throw Exception('تعذر إرسال طلب الانتساب.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final result = data['result'];
      final status = result is Map ? result['result_status']?.toString() : null;
      if (status == 'created' || status == 'already_created') {
        setState(() => success = 'تم إرسال طلب الانتساب بنجاح، وهو بانتظار مراجعة الجهة المختصة.');
      } else if (status == 'existing_pending') {
        setState(() => success = 'يوجد لديك طلب سابق قيد المراجعة.');
      } else if (status == 'auth_user_already_linked') {
        widget.onSubmitted();
      } else if (status == 'role_not_requestable') {
        setState(() => error = 'الدور المختار غير متاح لطلبات الانتساب.');
      } else if (status == 'station_not_available') {
        setState(() => error = 'المحطة المختارة غير متاحة.');
      } else if (status == 'terms_version_invalid') {
        setState(() => error = 'نسخة الشروط غير محدثة. أعد تحميل النموذج.');
      } else if (status == 'conflict') {
        setState(() => error = 'تعارض في الطلب. أعد تحميل الصفحة.');
      } else {
        setState(() => error = 'لم يتم إنشاء الطلب. حاول مجدداً.');
      }
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلب الانتساب'), actions: [
        IconButton(onPressed: () => Supabase.instance.client.auth.signOut(),
          tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout)),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData) {
            return _MessagePage(
              title: 'تعذر تحميل نموذج الانتساب',
              message: 'تعذر تحميل الأدوار والمحطات من الخدمة الآمنة.',
              action: 'إعادة المحاولة',
              onAction: () => setState(() => catalog = loadCatalog()),
            );
          }
          final roles = (snapshot.data!['roles'] as List? ?? const [])
            .whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
          final stations = (snapshot.data!['stations'] as List? ?? const [])
            .whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
          role ??= roles.isEmpty ? null : roles.first['role_code']?.toString();
          station ??= stations.isEmpty ? null : stations.first['id']?.toString();
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Text('بيانات مقدم الطلب', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('تُمنح الصلاحيات بعد اعتماد الحساب والعضوية، ولا يؤدي إرسال الطلب إلى تفعيلها تلقائياً.'),
            const SizedBox(height: 18),
            _TextField(controller: first, label: 'الاسم الأول'),
            _TextField(controller: father, label: 'اسم الأب'),
            _TextField(controller: last, label: 'اسم العائلة'),
            _TextField(controller: phone, label: 'رقم الهاتف (اختياري)', type: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'الدور المطلوب', border: OutlineInputBorder()),
              items: roles.map((x) => DropdownMenuItem<String>(
                value: x['role_code']?.toString(),
                child: Text((x['name_ar'] ?? x['role_code']).toString()),
              )).toList(),
              onChanged: busy ? null : (value) => setState(() => role = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: station,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'محطة الانتساب', border: OutlineInputBorder()),
              items: stations.map((x) => DropdownMenuItem<String>(
                value: x['id']?.toString(),
                child: Text(
                  (x['name_ar'] ?? '') .toString() + ' • ' +
                  (x['code'] ?? '').toString() + ' • ' +
                  (x['approval_status'] == 'approved' ? 'معتمدة' : 'قيد الاعتماد') + ' • ' +
                  (x['operational_status'] == 'active' ? 'تشغيلية' :
                    x['operational_status'] == 'inactive' ? 'متوقفة' : 'غير متحقق'),
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: busy ? null : (value) => setState(() => station = value),
            ),
            if (stations.isEmpty) const _InlineNotice('لا توجد محطات متاحة حالياً.', true),
            if (stations.any((item) => item['approval_status'] != 'approved' || item['operational_status'] != 'active'))
              const _InlineNotice(
                'تنبيه: لا يمكن إكمال اعتماد الانتساب لمحطة قبل اعتماد سجلها والتحقق من حالتها التشغيلية. ستظل الطلبات مرتبطة بمراجعة الجهة المختصة.',
                true,
              ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: terms,
              onChanged: busy ? null : (value) => setState(() => terms = value ?? false),
              title: const Text('أقر بصحة البيانات وأوافق على شروط استخدام النظام ومعالجة بيانات الحساب لأغراض العمل.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (error != null) _InlineNotice(error!, true),
            if (success != null) _InlineNotice(success!, false),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: busy || stations.isEmpty || roles.isEmpty ? null : submit,
              child: busy ? const CircularProgressIndicator() : const Text('إرسال طلب الانتساب'),
            )),
            if (success != null) TextButton(onPressed: widget.onSubmitted, child: const Text('متابعة حالة الطلب')),
          ]);
        },
      ),
    ),
  );
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.title, required this.message, this.loading = false,
    this.action, this.onAction, this.secondary, this.onSecondary,
  });
  final String title, message;
  final bool loading;
  final String? action, secondary;
  final VoidCallback? onAction, onSecondary;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(loading ? Icons.hourglass_top : Icons.verified_user_outlined, size: 54, color: const Color(0xFF1769D2)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
          if (secondary != null) TextButton(onPressed: onSecondary, child: Text(secondary!)),
        ]),
      ),
    ))),
  );
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.label, this.type});
  final TextEditingController controller;
  final String label;
  final TextInputType? type;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: type,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice(this.text, this.error);
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(color: error ? Colors.red.shade800 : Colors.green.shade800)),
  );
}


class RegistrationApprovalsPage extends StatefulWidget {
  const RegistrationApprovalsPage({super.key});
  @override
  State<RegistrationApprovalsPage> createState() => _RegistrationApprovalsPageState();
}

class _RegistrationApprovalsPageState extends State<RegistrationApprovalsPage> {
  late Future<List<Map<String, dynamic>>> queue;
  final Set<String> processingRequests = <String>{};

  @override
  void initState() {
    super.initState();
    queue = loadQueue();
  }

  Future<List<Map<String, dynamic>>> loadQueue() async {
    final response = await Supabase.instance.client.functions.invoke(
      'registration-approvals', body: const {'action': 'queue'},
    );
    if (response.status != 200 || response.data is! Map) {
      throw Exception('تعذر تحميل قائمة الاعتمادات أو لا توجد صلاحية للمراجعة.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['items'] as List? ?? const [])
      .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<String?> requestNote({required bool requiredNote}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(requiredNote ? 'سبب رفض الطلب' : 'ملاحظة المراجعة (اختياري)'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظة للمراجعة...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (requiredNote && value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  String decisionError(dynamic data) {
    final code = data is Map ? data['error']?.toString() : null;
    const messages = {
      'permission_denied': 'لا تملك صلاحية تنفيذ هذا القرار.',
      'account_not_active': 'الحساب غير نشط.',
      'registration_state_conflict': 'تغيرت حالة الطلب بواسطة مراجع آخر. حدّث القائمة.',
      'registration_request_not_found': 'الطلب غير موجود أو لم يعد متاحاً.',
      'invalid_decision_payload': 'بيانات القرار غير مكتملة أو غير صالحة.',
    };
    return messages[code] ?? 'تعذر تنفيذ قرار الاعتماد. تحقق من الاتصال والصلاحيات.';
  }

  String? expectedResultingStatus(String stage, String decision) {
    if (decision == 'reject' &&
        (stage == 'pending_station_approval' || stage == 'pending_system_approval')) {
      return 'rejected';
    }
    if (decision == 'approve' && stage == 'pending_station_approval') {
      return 'pending_system_approval';
    }
    if (decision == 'approve' && stage == 'pending_system_approval') {
      return 'active';
    }
    return null;
  }

  Future<void> decide(Map<String, dynamic> item, String decision) async {
    final requestId = item['id']?.toString() ?? '';
    if (requestId.isEmpty || processingRequests.contains(requestId)) return;
    setState(() => processingRequests.add(requestId));
    try {
      final note = await requestNote(requiredNote: decision == 'reject');
      if (note == null || !mounted) return;
      final expected = item['status']?.toString() ?? '';
      final expectedResult = expectedResultingStatus(expected, decision);
      if (expectedResult == null) {
        throw Exception('مرحلة الطلب أو القرار غير صالحين. حدّث القائمة.');
      }
      final response = await Supabase.instance.client.functions.invoke(
        'registration-approvals',
        body: {
          'action': 'decide',
          'request_id': requestId,
          'expected_status': expected,
          'decision': decision,
          'note': note,
        },
      );
      if (response.status != 200 || response.data is! Map) {
        throw Exception(decisionError(response.data));
      }
      final body = Map<String, dynamic>.from(response.data as Map);
      final result = body['result'];
      if (result is! Map ||
          result['result_status'] != 'committed' ||
          result['resulting_status'] != expectedResult) {
        if (result is Map && result['result_status'] == 'conflict') {
          throw Exception('تغيرت حالة الطلب. تم تحديث القائمة.');
        }
        throw Exception('لم يؤكد الخادم حفظ الحالة الناتجة المتوقعة للقرار.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ قرار المراجعة وتسجيله في سجل التدقيق.')),
      );
      setState(() => queue = loadQueue());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        if (e.toString().contains('تغيرت حالة الطلب')) {
          setState(() => queue = loadQueue());
        }
      }
    } finally {
      if (mounted) setState(() => processingRequests.remove(requestId));
    }
  }

  String applicantName(Map? profile) {
    if (profile == null) return 'مقدم طلب';
    return [
      profile['first_name'], profile['father_name'], profile['last_name'],
    ].where((value) => value is String && value.trim().isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('اعتمادات طلبات الانتساب'),
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            onPressed: () => setState(() => queue = loadQueue()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessagePage(
              title: 'تعذر تحميل الاعتمادات',
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              action: 'إعادة المحاولة',
              onAction: () => setState(() => queue = loadQueue()),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const _MessagePage(
              title: 'لا توجد طلبات بانتظارك',
              message: 'لا توجد طلبات ضمن نطاق المحطات أو مرحلة الاعتماد الممنوحة لحسابك حالياً.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final profile = item['applicant'] is Map ? item['applicant'] as Map : null;
              final station = item['station'] is Map ? item['station'] as Map : null;
              final stage = item['review_stage'] == 'station' ? 'اعتماد الجهة / المحطة' : 'الاعتماد النظامي النهائي';
              final stationName = station?['name_ar']?.toString() ?? 'محطة غير معروفة';
              final stationCode = station?['local_station_code']?.toString() ?? '';
              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.assignment_ind_outlined, color: Color(0xFF1769D2)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(applicantName(profile),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ]),
                    const SizedBox(height: 8),
                    Text(stage, style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text('المحطة: ' + stationName + (stationCode.isEmpty ? '' : ' • ' + stationCode)),
                    Text('الدور المطلوب: ' + (item['requested_role_code']?.toString() ?? 'غير محدد')),
                    Text('البريد/الهاتف لا يُعرضان هنا؛ بيانات الحساب محمية في شاشة الهوية.'),
                    const SizedBox(height: 12),
                    final requestId = item['id']?.toString() ?? '';
                    final isProcessing = processingRequests.contains(requestId);
                    Wrap(spacing: 8, children: [
                      FilledButton.icon(
                        onPressed: isProcessing ? null : () => decide(item, 'approve'),
                        icon: isProcessing
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: const Text('اعتماد'),
                      ),
                      OutlinedButton.icon(
                        onPressed: isProcessing ? null : () => decide(item, 'reject'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('رفض'),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
