class StationRecord {
  const StationRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.operationalStatus,
    required this.approvalStatus,
    this.latitude,
    this.longitude,
  });

  final String id, code, name, type, operationalStatus, approvalStatus;
  final double? latitude, longitude;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  String get normalizedType => type.trim().toLowerCase();
  String get normalizedApprovalStatus => approvalStatus.trim().toLowerCase();
  String get normalizedOperationalStatus => operationalStatus.trim().toLowerCase();

  bool get isClassic => normalizedType == 'classic';
  bool get isAutomatic => normalizedType == 'automatic';
  String get typeLabel => switch (normalizedType) {
    'classic' => 'كلاسيكية',
    'automatic' => 'آلية',
    _ => 'نوع غير معروف',
  };

  String get approvalLabel {
    switch (normalizedApprovalStatus) {
      case 'approved': return 'معتمدة';
      case 'rejected': return 'مرفوضة';
      case 'changes_requested': return 'تحتاج إلى تعديل';
      case 'pending': return 'بانتظار الاعتماد';
      default: return 'حالة الاعتماد غير معروفة';
    }
  }

  String get operationalLabel {
    switch (normalizedOperationalStatus) {
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
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    String text(Object? value, String fallback) {
      final result = value?.toString().trim() ?? '';
      return result.isEmpty ? fallback : result;
    }

    final arabic = json['name_ar']?.toString().trim() ?? '';
    return StationRecord(
      id: text(json['id'], ''),
      code: text(json['local_station_code'], ''),
      name: arabic.isNotEmpty
          ? arabic
          : text(json['name_en'], 'محطة دون اسم'),
      type: text(json['station_type'], 'unknown'),
      operationalStatus: text(json['operational_status'], 'unverified'),
      approvalStatus: text(json['approval_status'], 'pending'),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
    );
  }
}
