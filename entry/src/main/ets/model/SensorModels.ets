export interface SamplePoint {
  timeMs: number;
  values: number[];
}

export interface SensorRow {
  key: string;
  id: number;
  title: string;
  sensorName: string;
  vendor: string;
  unit: string;
  labels: string[];
  values: number[];
  history: SamplePoint[];
  status: string;
  message: string;
  enabled: boolean;
  lastReceivedMs: number;
  requestedIntervalNs: number;
  eventDriven: boolean;
}

export interface SensorSnapshot {
  rows: SensorRow[];
  paused: boolean;
  foreground: boolean;
  intervalMs: number;
  enumerationError: string;
  refreshing: boolean;
  excludedCount: number;
}

export interface SensorDefinition {
  id: number;
  title: string;
  unit: string;
  labels: string[];
  permission: string;
  eventDriven: boolean;
  minApi: number;
  qualification: boolean;
}
