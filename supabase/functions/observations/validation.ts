export const isValidObservationPayload = (type: string, value: Record<string, unknown>): boolean => {
  const ranges: Record<string, [number, number]> = {
    temperature_c: [-90, 65],
    humidity_percent: [0, 100],
    wind_speed_kmh: [0, 400],
    pressure_hpa: [800, 1100],
    precipitation_mm: [0, 2000],
  };
  const allowed = new Set([...Object.keys(ranges), "description"]);
  const keys = Object.keys(value);
  if (keys.length === 0 || keys.some((key) => !allowed.has(key))) return false;
  let measurementCount = 0;
  for (const [key, item] of Object.entries(value)) {
    if (key === "description") {
      if (typeof item !== "string" || item.trim().length === 0 || item.length > 2000) return false;
      continue;
    }
    const range = ranges[key];
    if (!range || typeof item !== "number" || !Number.isFinite(item) ||
        item < range[0] || item > range[1]) return false;
    measurementCount++;
  }
  if (type === "phenomenon") return typeof value.description === "string";
  return measurementCount > 0;
};

export const isValidObservedAt = (value: string, now = Date.now()): boolean => {
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp <= now + 5 * 60 * 1000;
};
