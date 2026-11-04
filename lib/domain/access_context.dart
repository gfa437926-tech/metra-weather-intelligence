class AccessContext {
  const AccessContext({
    this.roleCodes = const [],
    this.permissionCodes = const [],
  });

  final List<String> roleCodes;
  final List<String> permissionCodes;

  bool allows(String permissionCode) {
    final requested = permissionCode.trim();
    return requested.isNotEmpty && permissionCodes.contains(requested);
  }

  bool hasAnyPermission(Iterable<String> candidates) => candidates.any(allows);

  factory AccessContext.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    if (access is! Map) return const AccessContext();
    final data = Map<String, dynamic>.from(access);
    final memberships = data['memberships'];
    final permissions = data['permissions'];

    String? normalizedCode(dynamic value) {
      if (value is! String) return null;
      final code = value.trim();
      return code.isEmpty ? null : code;
    }

    final roles = <String>{};
    if (memberships is List) {
      for (final item in memberships.whereType<Map>()) {
        final role = normalizedCode(item['role_code']);
        if (role != null) roles.add(role);
      }
    }

    final permissionSet = <String>{};
    if (permissions is List) {
      for (final permission in permissions) {
        final code = normalizedCode(permission);
        if (code != null) permissionSet.add(code);
      }
    }

    return AccessContext(
      roleCodes: roles.toList()..sort(),
      permissionCodes: permissionSet.toList()..sort(),
    );
  }
}
