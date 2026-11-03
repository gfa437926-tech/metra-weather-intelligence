import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/station_record.dart';

void main() {
  StationRecord record({String approval = 'pending', String operational = 'unverified'}) =>
      StationRecord.fromJson({
        'id': '1',
        'local_station_code': 'TEST-01',
        'name_ar': 'محطة اختبار',
        'station_type': 'classic',
        'approval_status': approval,
        'operational_status': operational,
      });

  test('maps every known approval state to an explicit Arabic label', () {
    expect(record(approval: 'approved').approvalLabel, 'معتمدة');
    expect(record(approval: 'rejected').approvalLabel, 'مرفوضة');
    expect(record(approval: 'changes_requested').approvalLabel, 'تحتاج إلى تعديل');
    expect(record().approvalLabel, 'بانتظار الاعتماد');
    expect(record(approval: 'unexpected').approvalLabel, 'حالة الاعتماد غير معروفة');
  });

  test('maps operational lifecycle without implying unknown means inactive', () {
    expect(record(operational: 'active').operationalLabel, 'فعالة');
    expect(record(operational: 'inactive').operationalLabel, 'متوقفة');
    expect(record(operational: 'suspended').operationalLabel, 'معلّقة');
    expect(record(operational: 'decommissioned').operationalLabel, 'خارج الخدمة');
    expect(record().operationalLabel, 'غير متحقق منها');
    expect(record(operational: 'unexpected').operationalLabel, 'حالة التشغيل غير معروفة');
  });
}
