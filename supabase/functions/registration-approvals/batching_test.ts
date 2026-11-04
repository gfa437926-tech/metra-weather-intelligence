import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { chunkValues } from "./batching.ts";

Deno.test("chunks values without losing order or values", () => {
  assertEquals(chunkValues([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

Deno.test("empty input returns no chunks", () => {
  assertEquals(chunkValues([], 200), []);
});

Deno.test("exact batch boundary returns one chunk", () => {
  assertEquals(chunkValues([1, 2], 2), [[1, 2]]);
});

Deno.test("invalid chunk size is rejected", () => {
  assertThrows(() => chunkValues([1], 0), RangeError);
});
