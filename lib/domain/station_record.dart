class StationRecord {
  const StationRecord({
    required this.id, required this.code, required this.name, required this.type,
    required this.operationalStatus, required this.approvalStatus,
    this.latitude, this.longitude,
  });
  final String id, code, name, type, operationalStatus, approvalStatus;
  final double? latitude, longitude;

  bool get hasCoordinates => latitude != null && longitude != null &&
      latitude!.isFinite && longitude!.isFinite &&
      latitude! >= -90 && latitude! <= 90 &&
      longitude! >= -180 && longitude! <= 180;
  bool get isClassic => type.toLowerCase() == 'classic';
  String get typeLabel => isClassic ? 'كلاسيكية' : 'آلية';

  String get approvalLabel {
    switch (approvalStatus.toLowerCase()) {
      case 'approved': return 'معتمدة';
      case 'rejected': return 'مرفوضة';
      case 'changes_requested': return 'تحتاج إلى تعديل';
      case 'pending': return 'بانتظار الاعتماد';
      default: return 'حالة الاعتماد غير معروفة';
    }
  }

  String get operationalLabel {
    switch (operationalStatus.toLowerCase()) {
      case 'active': return 'فعالة';
      case 'inactive': return 'متوقفة';
      case 'suspended': return 'معلّقة';
      case 'decommissioned': return 'خارج الخدمة';
      case 'unverified': return 'غير متحقق منها';
      default: return 'حالة التشغيل غير معروفة';
    }
  }

  factory StationRecord.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }
    final arabic = json['name_ar']?.toString().trim() ?? '';
    return StationRecord(
      id: json['id']?.toString() ?? '',
      code: json['local_station_code']?.toString() ?? '',
      name: arabic.isNotEmpty ? arabic : (json['name_en']?.toString() ?? 'محطة دون اسم'),
      type: json['station_type']?.toString() ?? 'automatic',
      operationalStatus: json['operational_status']?.toString() ?? 'unverified',
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
    );
  }
}
