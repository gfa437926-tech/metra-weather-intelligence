import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/domain/access_context.dart';

void main() {
  test('parses approved roles and effective permissions', () {
    final context = AccessContext.fromJson({
      'access': {
        'memberships': [
          {'role_code': 'observer'},
          {'role_code': 'station_head'},
          {'role_code': 'observer'},
        ],
        'permissions': [
          'observation.create',
          'observation.submit',
          'observation.create',
        ],
      },
    });
    expect(context.roleCodes, ['observer', 'station_head']);
    expect(context.permissionCodes, ['observation.create', 'observation.submit']);
  });

  test('trims codes and ignores blank or malformed entries', () {
    final context = AccessContext.fromJson({
      'access': {
        'memberships': [
          {'role_code': ' observer '},
          {'role_code': '  '},
          null,
          {'role_code': 42},
          {'role_code': 'observer'},
        ],
        'permissions': [
          ' observation.read ',
          '',
          '   ',
          null,
          9,
          'observation.read',
        ],
      },
    });
    expect(context.roleCodes, ['observer']);
    expect(context.permissionCodes, ['observation.read']);
  });

  test('missing access context is safely empty, never elevated', () {
    final context = AccessContext.fromJson({'stations': []});
    expect(context.roleCodes, isEmpty);
    expect(context.permissionCodes, isEmpty);
  });

  test('malformed access values remain safely empty', () {
    final context = AccessContext.fromJson({
      'access': {'memberships': 'invalid', 'permissions': {'unexpected': true}},
    });
    expect(context.roleCodes, isEmpty);
    expect(context.permissionCodes, isEmpty);
  });
}
