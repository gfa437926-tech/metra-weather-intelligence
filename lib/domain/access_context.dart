class AccessContext {
  const AccessContext({
    this.roleCodes = const [],
    this.permissionCodes = const [],
  });

  final List<String> roleCodes;
  final List<String> permissionCodes;

  factory AccessContext.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    if (access is! Map) return const AccessContext();
    final data = Map<String, dynamic>.from(access);
    final memberships = data['memberships'];
    final permissions = data['permissions'];
    return AccessContext(
      roleCodes: memberships is List
          ? memberships.whereType<Map>()
              .map((item) => item['role_code'])
              .whereType<String>().toSet().toList()..sort()
          : const [],
      permissionCodes: permissions is List
          ? permissions.whereType<String>().toSet().toList()..sort()
          : const [],
    );
  }
}
