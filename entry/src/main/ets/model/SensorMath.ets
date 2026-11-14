import { SamplePoint, SensorRow } from './SensorModels';

export const HISTORY_LIMIT: number = 240;
export const HISTORY_WINDOW_MS: number = 60000;

// Options.interval and SDK sampling periods are expressed in nanoseconds.
export function clampIntervalNs(intervalMs: number, minNs: number, maxNs: number): number {
  let interval: number = intervalMs * 1000000;
  if (Number.isFinite(minNs) && minNs > 0) {
    interval = Math.max(interval, minNs);
  }
  if (Number.isFinite(maxNs) && maxNs > 0 && maxNs >= minNs) {
    interval = Math.min(interval, maxNs);
  }
  return interval;
}

export function finiteValues(values: number[], expected: number): boolean {
  return values.length === expected && values.length > 0 &&
    values.every((value: number) => typeof value === 'number' && Number.isFinite(value));
}

export function appendHistory(history: SamplePoint[], timeMs: number, values: number[]): SamplePoint[] {
  const oldest: number = timeMs - HISTORY_WINDOW_MS;
  const points: SamplePoint[] = history.filter((point: SamplePoint) => point.timeMs >= oldest);
  points.push({ timeMs: timeMs, values: values.slice() });
  if (points.length > HISTORY_LIMIT) {
    return points.slice(points.length - HISTORY_LIMIT);
  }
  return points;
}

export function staleAfterMs(intervalNs: number): number {
  return Math.max(5000, intervalNs / 1000000 * 5);
}

export function readingStatus(row: SensorRow, nowMs: number, startedMs: number, receivedThisSession: boolean): string {
  if (row.eventDriven) {
    return receivedThisSession ? 'live' : 'waiting';
  }
  const lastMs: number = receivedThisSession ? row.lastReceivedMs : startedMs;
  if (nowMs - lastMs > staleAfterMs(row.requestedIntervalNs)) {
    return 'stale';
  }
  return receivedThisSession ? 'live' : 'waiting';
}

export function copyRow(row: SensorRow, includeHistory: boolean = true): SensorRow {
  return {
    key: row.key, id: row.id, title: row.title, sensorName: row.sensorName,
    vendor: row.vendor, unit: row.unit, labels: row.labels.slice(), values: row.values.slice(),
    history: includeHistory ? row.history.map((point: SamplePoint): SamplePoint => {
      return { timeMs: point.timeMs, values: point.values.slice() };
    }) : [],
    status: row.status, message: row.message, enabled: row.enabled,
    lastReceivedMs: row.lastReceivedMs, requestedIntervalNs: row.requestedIntervalNs, eventDriven: row.eventDriven
  };
}
