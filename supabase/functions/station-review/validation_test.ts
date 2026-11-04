import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isValidStationReviewDecision } from "./validation.ts";

const stationId = "7f6d8c10-3b4a-4e2f-9a1c-123456789abc";

Deno.test("accepts each supported station review decision", () => {
  for (const decision of ["approved", "rejected", "changes_requested"]) {
    assertEquals(isValidStationReviewDecision({
      action: "decide", station_id: stationId, decision, reason: "تم التحقق من البيانات",
    }), true);
  }
});

Deno.test("rejects malformed station identifiers and unsupported decisions", () => {
  assertEquals(isValidStationReviewDecision({
    action: "decide", station_id: "not-a-uuid", decision: "approved", reason: "سبب صحيح",
  }), false);
  assertEquals(isValidStationReviewDecision({
    action: "decide", station_id: stationId, decision: "activate", reason: "سبب صحيح",
  }), false);
});

Deno.test("requires a meaningful bounded decision reason", () => {
  for (const reason of ["", "   ", "قصير", "x".repeat(2001)]) {
    assertEquals(isValidStationReviewDecision({
      action: "decide", station_id: stationId, decision: "approved", reason,
    }), false);
  }
  assertEquals(isValidStationReviewDecision({
    action: "decide", station_id: stationId, decision: "approved", reason: "مقبول",
  }), true);
});

Deno.test("rejects non-object and client-forged payload shapes", () => {
  assertEquals(isValidStationReviewDecision(null), false);
  assertEquals(isValidStationReviewDecision([]), false);
  assertEquals(isValidStationReviewDecision({
    action: "decide", station_id: stationId, decision: "approved", reason: "مقبول", actor_id: stationId,
  }), true);
});
