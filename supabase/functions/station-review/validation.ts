export type StationReviewDecisionPayload = {
  action: "decide";
  station_id: string;
  decision: "approved" | "rejected" | "changes_requested";
  reason: string;
};

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isValidStationReviewDecision(
  value: unknown,
): value is StationReviewDecisionPayload {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const payload = value as Record<string, unknown>;
  if (payload.action !== "decide" ||
      typeof payload.station_id !== "string" ||
      !UUID_PATTERN.test(payload.station_id) ||
      typeof payload.decision !== "string" ||
      !["approved", "rejected", "changes_requested"].includes(payload.decision) ||
      typeof payload.reason !== "string") {
    return false;
  }
  const reason = payload.reason.trim();
  return reason.length >= 5 && reason.length <= 2000;
}
