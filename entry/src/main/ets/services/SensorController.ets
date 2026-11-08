import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { sensor } from '@kit.SensorServiceKit';
import { SensorDefinition, SensorRow, SensorSnapshot } from '../model/SensorModels';
import { definitionFor } from '../model/SensorCatalog';
import { appendHistory, clampIntervalNs, copyRow, finiteValues, readingStatus } from '../model/SensorMath';
import { subscribeNative, StopSubscription } from './NativeSensorAdapter';

class SensorBinding {
  row: SensorRow;
  metadata: sensor.Sensor;
  definition: SensorDefinition | undefined;
  stop: StopSubscription | undefined = undefined;
  startedMs: number = 0;
  receivedThisSession: boolean = false;
  generation: number = 0;
  unsupportedReason: string = '';

  constructor(row: SensorRow, metadata: sensor.Sensor, definition: SensorDefinition | undefined) {
    this.row = row;
    this.metadata = metadata;
    this.definition = definition;
  }
}

// Singleton per UIAbility process. No storage, network, distributed sensors, or background task.
export class SensorController {
  private static instance: SensorController | undefined = undefined;
  onChange: (() => void) | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private bindings: SensorBinding[] = [];
  private paused: boolean = false;
  private foreground: boolean = false;
  private intervalMs: number = 200;
  private enumerationError: string = '';
  private refreshing: boolean = false;
  private excludedCount: number = 0;
  private revision: number = 0;
  private timer: number = -1;
  private notifyTimer: number = -1;
  private permissionRequestPending: boolean = false;
  private stoppedBindings: SensorBinding[] = [];

  static shared(): SensorController {
    if (SensorController.instance === undefined) {
      SensorController.instance = new SensorController();
    }
    return SensorController.instance;
  }

  attach(context: common.UIAbilityContext): void {
    this.context = context;
  }

  snapshot(): SensorSnapshot {
    return {
      rows: this.bindings.map((binding: SensorBinding): SensorRow => copyRow(binding.row)),
      paused: this.paused, foreground: this.foreground, intervalMs: this.intervalMs,
      enumerationError: this.enumerationError, refreshing: this.refreshing, excludedCount: this.excludedCount
    };
  }

  setForeground(foreground: boolean): void {
    if (this.foreground === foreground) {
      return;
    }
    this.foreground = foreground;
    this.restart();
  }

  setPaused(paused: boolean): void {
    if (this.paused === paused) {
      return;
    }
    this.paused = paused;
    this.restart();
  }

  setIntervalMs(intervalMs: number): void {
    if (![1000, 200, 100, 50].includes(intervalMs) || this.intervalMs === intervalMs) {
      return;
    }
    this.intervalMs = intervalMs;
    this.bindings.forEach((binding: SensorBinding) => {
      binding.row.requestedIntervalNs = clampIntervalNs(intervalMs,
        binding.metadata.minSamplePeriod, binding.metadata.maxSamplePeriod);
    });
    this.restart();
  }

  setEnabled(key: string, enabled: boolean): void {
    const binding: SensorBinding | undefined = this.bindings.find((item: SensorBinding) => item.row.key === key);
    if (binding === undefined || binding.row.enabled === enabled) {
      return;
    }
    binding.row.enabled = enabled;
    this.restart();
  }

  clearHistory(): void {
    this.bindings.forEach((binding: SensorBinding) => binding.row.history = []);
    this.notifyNow();
  }

  async refresh(): Promise<void> {
    this.revision++;
    this.stopAll();
    this.refreshing = true;
    this.enumerationError = '';
    this.notifyNow();
    try {
      // API19 explicitly queries device -1 (local); older getSensorListSync is local-only.
      let metadata: sensor.Sensor[];
      if (deviceInfo.apiAvailable(19)) {
        metadata = sensor.getSensorListByDeviceSync(-1);
      } else {
        metadata = sensor.getSensorListSync();
      }
      const previous: SensorBinding[] = this.bindings;
      const next: SensorBinding[] = [];
      let excluded: number = 0;
      metadata.forEach((item: sensor.Sensor) => {
        if ((deviceInfo.apiAvailable(19) && item.isLocalSensor === false) ||
          (deviceInfo.apiAvailable(23) && item.isMockSensor === true)) {
          excluded++;
          return;
        }
        const definition: SensorDefinition | undefined = definitionFor(item.sensorId);
        const index: number = deviceInfo.apiAvailable(19) && item.sensorIndex !== undefined ? item.sensorIndex : 0;
        const key: string = item.sensorId.toString() + ':' + index.toString();
        if (next.some((binding: SensorBinding) => binding.row.key === key)) {
          // Old APIs cannot address another sensor of the same type; never label a default callback as its reading.
          excluded++;
          return;
        }
        const old: SensorBinding | undefined = previous.find((binding: SensorBinding) => binding.row.key === key);
        const row: SensorRow = {
          key: key, id: item.sensorId, title: definition === undefined ? '未适配传感器 ' + item.sensorId : definition.title,
          sensorName: item.sensorName, vendor: item.vendorName,
          unit: definition === undefined ? '' : definition.unit,
          labels: definition === undefined ? [] : definition.labels.slice(),
          values: [], history: [], status: 'waiting', message: '等待本机样本',
          enabled: old === undefined ? true : old.row.enabled, lastReceivedMs: 0,
          requestedIntervalNs: clampIntervalNs(this.intervalMs, item.minSamplePeriod, item.maxSamplePeriod),
          eventDriven: definition === undefined ? false : definition.eventDriven
        };
        const binding: SensorBinding = new SensorBinding(row, item, definition);
        if (definition === undefined) {
          binding.unsupportedReason = '已枚举此硬件，尚无已核验的公开数据适配器';
        } else if (deviceInfo.sdkApiVersion < definition.minApi) {
          binding.unsupportedReason = '此接口需要 API ' + definition.minApi.toString() + ' 或更高版本';
        }
        next.push(binding);
      });
      this.bindings = next;
      this.excludedCount = excluded;
    } catch (error) {
      this.bindings = [];
      this.enumerationError = this.describeError(error as BusinessError);
    }
    this.refreshing = false;
    this.restart();
  }

  // Invoked only from an explicit user action. A late permission result cannot restart collection in the background.
  async authorizeMotion(): Promise<void> {
    if (this.context === undefined || !this.foreground || this.permissionRequestPending) {
      return;
    }
    this.permissionRequestPending = true;
    try {
      const manager = abilityAccessCtrl.createAtManager();
      await manager.requestPermissionsFromUser(this.context, ['ohos.permission.ACTIVITY_MOTION']);
    } catch (error) {
      const message: string = this.describeError(error as BusinessError);
      this.bindings.forEach((binding: SensorBinding) => {
        if (binding.definition !== undefined && binding.definition.permission === 'ohos.permission.ACTIVITY_MOTION') {
          binding.row.status = 'permission';
          binding.row.message = message;
        }
      });
    } finally {
      this.permissionRequestPending = false;
      this.restart();
    }
  }

  dispose(): void {
    this.foreground = false;
    this.revision++;
    this.stopAll();
    this.bindings = [];
    this.context = undefined;
    if (this.notifyTimer !== -1) {
      clearTimeout(this.notifyTimer);
      this.notifyTimer = -1;
    }
    this.onChange = undefined;
  }

  private restart(): void {
    this.revision++;
    this.stopAll();
    this.bindings.forEach((binding: SensorBinding) => this.updateIdleStatus(binding));
    if (this.foreground && !this.paused && !this.refreshing) {
      this.bindings.forEach((binding: SensorBinding) => this.startBinding(binding));
      this.timer = setInterval(() => this.tick(), 1000);
    }
    this.notifyNow();
  }

  private updateIdleStatus(binding: SensorBinding): void {
    const row: SensorRow = binding.row;
    if (binding.definition !== undefined && binding.definition.qualification) {
      row.status = 'qualification';
      row.message = '健康功能单独核验中；首版不采集心率';
    } else if (binding.unsupportedReason.length > 0) {
      row.status = 'unsupported';
      row.message = binding.unsupportedReason;
    } else if (binding.stop !== undefined) {
      row.status = 'error';
      row.message = '原生订阅尚未成功停止；已屏蔽回调，可刷新重试清理';
    } else if (!row.enabled) {
      row.status = 'disabled';
      row.message = '此传感器已关闭';
    } else if (!this.foreground) {
      row.status = 'background';
      row.message = '应用在后台，已停止采集';
    } else if (this.paused) {
      row.status = 'paused';
      row.message = '已暂停；保留的是暂停前的数值';
    } else if (!this.hasPermission(binding)) {
      row.status = 'permission';
      row.message = this.permissionMessage(binding);
    } else {
      row.status = 'waiting';
      row.message = row.eventDriven ? '等待事件；静止时可能不回调' : '等待本机新样本';
    }
  }

  private startBinding(binding: SensorBinding): void {
    if (binding.stop !== undefined || !this.foreground || this.paused || !binding.row.enabled || binding.unsupportedReason.length > 0 ||
      binding.definition === undefined || binding.definition.qualification || !this.hasPermission(binding)) {
      return;
    }
    const revision: number = this.revision;
    binding.generation++;
    const generation: number = binding.generation;
    binding.startedMs = Date.now();
    binding.receivedThisSession = false;
    // Retain cached value time; readingStatus requires a sample from this subscription before marking it live.
    const options: sensor.Options = { interval: binding.row.requestedIntervalNs };
    if (deviceInfo.apiAvailable(19)) {
      options.sensorInfoParam = { deviceId: -1, sensorIndex: binding.metadata.sensorIndex === undefined ? 0 : binding.metadata.sensorIndex };
    }
    try {
      binding.stop = subscribeNative(binding.row, options, (values: number[], labels?: string[]) => {
        if (revision !== this.revision || generation !== binding.generation || !this.foreground || this.paused ||
          !binding.row.enabled) {
          return;
        }
        if (!this.hasPermission(binding)) {
          this.stopBinding(binding);
          binding.row.status = 'permission';
          binding.row.message = this.permissionMessage(binding);
          this.notifyNow();
          return;
        }
        const expected: number = labels === undefined ? binding.row.labels.length : labels.length;
        if (!finiteValues(values, expected)) {
          binding.row.status = 'error';
          binding.row.message = '设备返回了缺失或非有限数值；该样本未显示';
          this.notifyNow();
          return;
        }
        const nowMs: number = Date.now();
        // History is display-decimated to the chosen UI frequency; no interpolation or invented samples.
        if (!binding.row.eventDriven && binding.receivedThisSession && binding.row.lastReceivedMs > 0 &&
          nowMs - binding.row.lastReceivedMs < this.intervalMs) {
          return;
        }
        if (labels !== undefined) {
          if (labels.join('|') !== binding.row.labels.join('|')) {
            // Never associate an old component history with a different optional-field layout.
            binding.row.history = [];
          }
          binding.row.labels = labels.slice();
          binding.row.unit = labels.length > 1 ? '见分量' : 'lx';
        }
        binding.receivedThisSession = true;
        binding.row.values = values.slice();
        binding.row.lastReceivedMs = nowMs;
        binding.row.history = appendHistory(binding.row.history, nowMs, values);
        binding.row.status = 'live';
        binding.row.message = binding.row.eventDriven ? '按事件上报；频率由硬件决定' :
          binding.row.id === sensor.SensorId.AMBIENT_LIGHT && values.length > 1 ?
          '附加光照字段可能是驱动占位值，应核实硬件支持' : '本机 API 实时样本';
        this.notifyLater();
      });
    } catch (error) {
      binding.stop = undefined;
      const businessError: BusinessError = error as BusinessError;
      binding.row.status = businessError.code === 201 ? 'permission' :
        businessError.code === 14500102 ? 'unsupported' : 'error';
      binding.row.message = this.describeError(businessError);
    }
  }

  private hasPermission(binding: SensorBinding): boolean {
    if (binding.definition === undefined || binding.definition.permission.length === 0) {
      return true;
    }
    if (this.context === undefined) {
      return false;
    }
    try {
      const permission: Permissions = binding.definition.permission as Permissions;
      return abilityAccessCtrl.createAtManager().checkAccessTokenSync(
        this.context.applicationInfo.accessTokenId, permission) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      return false;
    }
  }

  private permissionMessage(binding: SensorBinding): string {
    return binding.definition !== undefined && binding.definition.permission === 'ohos.permission.ACTIVITY_MOTION' ?
      '需要运动权限；点击“授权运动”后可启用' : '必要的系统权限未获授予，无法采集';
  }

  private stopBinding(binding: SensorBinding): void {
    binding.generation++;
    if (binding.stop === undefined) {
      return;
    }
    try {
      binding.stop();
      binding.stop = undefined;
    } catch (error) {
      // Retain the stop callback to retry native cleanup. Generation rejects any late callback in the meantime.
      if (!this.stoppedBindings.includes(binding)) {
        this.stoppedBindings.push(binding);
      }
      binding.row.status = 'error';
      binding.row.message = '停止订阅失败：' + this.describeError(error as BusinessError);
    }
  }

  private stopAll(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    const pending: SensorBinding[] = this.stoppedBindings.slice();
    this.stoppedBindings = [];
    pending.forEach((binding: SensorBinding) => this.stopBinding(binding));
    this.bindings.forEach((binding: SensorBinding) => this.stopBinding(binding));
  }

  private tick(): void {
    if (!this.foreground || this.paused) {
      return;
    }
    this.bindings.forEach((binding: SensorBinding) => {
      if (binding.stop === undefined) {
        return;
      }
      if (!this.hasPermission(binding)) {
        this.stopBinding(binding);
        binding.row.status = 'permission';
        binding.row.message = this.permissionMessage(binding);
        return;
      }
      if (binding.row.status === 'error') {
        return;
      }
      const status: string = readingStatus(binding.row, Date.now(), binding.startedMs, binding.receivedThisSession);
      binding.row.status = status;
      if (status === 'stale') {
        binding.row.message = '暂未收到新样本；可能由硬件频率或按变化上报造成，可刷新重试';
      }
    });
    this.notifyNow();
  }

  private describeError(error: BusinessError): string {
    switch (error.code) {
      case 201: return '必要权限未获授予或已撤销 (201)';
      case 202: return '此功能需要系统应用资格，普通应用不可调用 (202)';
      case 401: return '传感器参数或频率不被设备接受 (401)';
      case 801: return '此设备不支持该系统能力 (801)';
      case 14500101: return '传感器服务异常，可刷新重试 (14500101)';
      case 14500102: return '该设备不支持此传感器 (14500102)';
      default: return '传感器操作失败' + (error.code === undefined ? '' : ' (' + error.code.toString() + ')');
    }
  }

  private notifyLater(): void {
    if (this.notifyTimer !== -1) {
      return;
    }
    this.notifyTimer = setTimeout(() => {
      this.notifyTimer = -1;
      this.notifyNow();
    }, Math.min(this.intervalMs, 200));
  }

  private notifyNow(): void {
    if (this.onChange !== undefined) {
      this.onChange();
    }
  }
}
