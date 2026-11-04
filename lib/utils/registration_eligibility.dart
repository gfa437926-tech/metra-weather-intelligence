bool isRegistrationStationEligible(Map<String, dynamic> station) =>
    station['approval_status'] == 'approved' &&
    station['operational_status'] == 'active';

bool isRegistrationStationSelectionEligible(
  Iterable<dynamic> stations,
  String? selectedStationId,
) {
  if (selectedStationId == null || selectedStationId.isEmpty) return false;
  for (final item in stations) {
    if (item is Map && item['id']?.toString() == selectedStationId) {
      return isRegistrationStationEligible(Map<String, dynamic>.from(item));
    }
  }
  return false;
}
