/// Returns true only for explicit station-directory read permission.
export function canReadStationDirectory(permissionCodes: readonly string[]): boolean {
  return permissionCodes.includes("stations.read") ||
    permissionCodes.includes("station.read");
}
