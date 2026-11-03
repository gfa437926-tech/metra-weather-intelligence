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

    final roles = <String>{};
    if (memberships is List) {
      for (final item in memberships.whereType<Map>()) {
        final role = item['role_code'];
        if (role is String && role.isNotEmpty) roles.add(role);
      }
    }

    final permissionSet = <String>{};
    if (permissions is List) {
      for (final permission in permissions) {
        if (permission is String && permission.isNotEmpty) {
          permissionSet.add(permission);
        }
      }
    }

    return AccessContext(
      roleCodes: roles.toList()..sort(),
      permissionCodes: permissionSet.toList()..sort(),
    );
  }
}
