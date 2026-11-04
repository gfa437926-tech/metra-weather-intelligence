import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isValidObservationPayload, isValidObservedAt, isValidObservationSubmissionResult } from "./validation.ts";

Deno.test("accepts a bounded daily observation", () => {
  assertEquals(isValidObservationPayload("daily", {
    temperature_c: 23.4, humidity_percent: 55, wind_speed_kmh: 12,
  }), true);
});

Deno.test("rejects out-of-range and non-finite measurements", () => {
  assertEquals(isValidObservationPayload("hourly", { humidity_percent: 120 }), false);
  assertEquals(isValidObservationPayload("hourly", { temperature_c: Number.NaN }), false);
  assertEquals(isValidObservationPayload("hourly", { pressure_hpa: 500 }), false);
});

Deno.test("rejects unknown fields and empty payloads", () => {
  assertEquals(isValidObservationPayload("daily", {}), false);
  assertEquals(isValidObservationPayload("daily", { user_id: "spoofed" }), false);
});

Deno.test("phenomenon observations require a non-empty description", () => {
  assertEquals(isValidObservationPayload("phenomenon", { description: "غبار" }), true);
  assertEquals(isValidObservationPayload("phenomenon", { description: " " }), false);
  assertEquals(isValidObservationPayload("phenomenon", { temperature_c: 22 }), false);
});

Deno.test("observed timestamps cannot be materially in the future", () => {
  const now = Date.UTC(2026, 10, 4, 0, 0, 0);
  assertEquals(isValidObservedAt(new Date(now).toISOString(), now), true);
  assertEquals(isValidObservedAt(new Date(now + 6 * 60 * 1000).toISOString(), now), false);
  assertEquals(isValidObservedAt("not-a-date", now), false);
});


Deno.test("accepts only a confirmed observation submission result", () => {
  assertEquals(isValidObservationSubmissionResult({
    id: "observation-1", status: "submitted", replayed: false,
  }, "submitted"), true);
  assertEquals(isValidObservationSubmissionResult({
    id: "observation-1", status: "draft", replayed: true,
  }, "draft"), true);
});

Deno.test("rejects malformed or mismatched observation submission results", () => {
  assertEquals(isValidObservationSubmissionResult(null, "submitted"), false);
  assertEquals(isValidObservationSubmissionResult([], "submitted"), false);
  assertEquals(isValidObservationSubmissionResult({
    id: "observation-1", status: "draft", replayed: false,
  }, "submitted"), false);
  assertEquals(isValidObservationSubmissionResult({
    id: "", status: "submitted", replayed: false,
  }, "submitted"), false);
  assertEquals(isValidObservationSubmissionResult({
    id: "observation-1", status: "submitted", replayed: "false",
  }, "submitted"), false);
});
