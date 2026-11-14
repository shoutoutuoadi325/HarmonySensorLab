import { SensorRow } from './SensorModels';

// Live readings update visible cards independently of the list's hardware keys.
export class WatchSensorList implements IDataSource {
  private rows: SensorRow[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.rows.length;
  }

  getData(index: number): SensorRow {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }

  update(rows: SensorRow[]): void {
    if (this.rows.length === rows.length &&
      rows.every((row: SensorRow, index: number) => row.key === this.rows[index].key)) { return; }
    this.rows = rows;
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}
