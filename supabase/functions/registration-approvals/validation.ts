export type RegistrationStage =
  | "pending_station_approval"
  | "pending_system_approval";
export type RegistrationDecision = "approve" | "reject";

export function expectedRegistrationResult(
  stage: string,
  decision: string,
): string | null {
  if (decision === "reject" &&
      (stage === "pending_station_approval" || stage === "pending_system_approval")) {
    return "rejected";
  }
  if (decision === "approve" && stage === "pending_station_approval") {
    return "pending_system_approval";
  }
  if (decision === "approve" && stage === "pending_system_approval") {
    return "active";
  }
  return null;
}

export function isValidRegistrationDecisionResult(
  value: unknown,
  expectedStage: string,
  decision: string,
): value is { result_status: "committed"; resulting_status: string } {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const result = value as Record<string, unknown>;
  const expected = expectedRegistrationResult(expectedStage, decision);
  return expected !== null &&
    result.result_status === "committed" &&
    result.resulting_status === expected;
}
