import { canReadStationDirectory } from "./permissions.ts";

Deno.test("grants directory access for the canonical permission", () => {
  if (!canReadStationDirectory(["stations.read"])) {
    throw new Error("stations.read should grant directory access");
  }
});

Deno.test("supports the legacy singular permission code", () => {
  if (!canReadStationDirectory(["station.read"])) {
    throw new Error("station.read should grant directory access");
  }
});

Deno.test("does not infer directory access from unrelated permissions", () => {
  if (canReadStationDirectory(["observations.read", "alerts.read"])) {
    throw new Error("unrelated permissions must not grant station access");
  }
});

Deno.test("fails closed for empty permission assignments", () => {
  if (canReadStationDirectory([])) {
    throw new Error("empty permission assignments must be denied");
  }
});
