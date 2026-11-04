import 'package:flutter_test/flutter_test.dart';
import 'package:metra_weather_intelligence/utils/registration_eligibility.dart';

void main() {
  Map<String, dynamic> station({
    String id = 'station-1',
    String approval = 'approved',
    String operational = 'active',
  }) => {
    'id': id,
    'approval_status': approval,
    'operational_status': operational,
  };

  test('only approved and operationally active stations are eligible', () {
    expect(isRegistrationStationEligible(station()), isTrue);
    expect(isRegistrationStationEligible(station(approval: 'pending')), isFalse);
    expect(isRegistrationStationEligible(station(approval: 'rejected')), isFalse);
    expect(isRegistrationStationEligible(station(operational: 'unverified')), isFalse);
    expect(isRegistrationStationEligible(station(operational: 'inactive')), isFalse);
  });

  test('selection must match an eligible station in the loaded catalogue', () {
    final stations = [
      station(id: 'pending', approval: 'pending'),
      station(id: 'active'),
    ];
    expect(isRegistrationStationSelectionEligible(stations, 'active'), isTrue);
    expect(isRegistrationStationSelectionEligible(stations, 'pending'), isFalse);
    expect(isRegistrationStationSelectionEligible(stations, 'missing'), isFalse);
    expect(isRegistrationStationSelectionEligible(stations, null), isFalse);
  });

  test('malformed catalogue entries cannot make a selection eligible', () {
    expect(isRegistrationStationSelectionEligible([null, 'bad'], 'station-1'), isFalse);
    expect(isRegistrationStationSelectionEligible([{'id': 'station-1'}], 'station-1'), isFalse);
  });
}
