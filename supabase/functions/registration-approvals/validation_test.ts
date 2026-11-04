import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  expectedRegistrationResult,
  isValidRegistrationDecisionResult,
} from "./validation.ts";

Deno.test("maps both approval stages to their exact next state", () => {
  assertEquals(expectedRegistrationResult("pending_station_approval", "approve"), "pending_system_approval");
  assertEquals(expectedRegistrationResult("pending_system_approval", "approve"), "active");
  assertEquals(expectedRegistrationResult("pending_station_approval", "reject"), "rejected");
  assertEquals(expectedRegistrationResult("pending_system_approval", "reject"), "rejected");
});

Deno.test("accepts only committed results with the exact expected resulting state", () => {
  assertEquals(isValidRegistrationDecisionResult({
    result_status: "committed", resulting_status: "pending_system_approval",
  }, "pending_station_approval", "approve"), true);
  assertEquals(isValidRegistrationDecisionResult({
    result_status: "committed", resulting_status: "active",
  }, "pending_system_approval", "approve"), true);
  assertEquals(isValidRegistrationDecisionResult({
    result_status: "committed", resulting_status: "rejected",
  }, "pending_station_approval", "reject"), true);
});

Deno.test("rejects null, malformed, conflict and mismatched transaction results", () => {
  for (const value of [
    null,
    [],
    {},
    { result_status: "conflict", resulting_status: "pending_station_approval" },
    { result_status: "committed", resulting_status: "active" },
  ]) {
    assertEquals(isValidRegistrationDecisionResult(value, "pending_station_approval", "approve"), false);
  }
  assertEquals(isValidRegistrationDecisionResult({
    result_status: "committed", resulting_status: "active",
  }, "unknown_stage", "approve"), false);
});
