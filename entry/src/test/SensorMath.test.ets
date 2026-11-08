import { appendHistory, clampIntervalNs, finiteValues, HISTORY_LIMIT } from '../main/ets/model/SensorMath';
import { SamplePoint } from '../main/ets/model/SensorModels';

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

// Framework-free ArkTS assertions, suitable for invoking from a dedicated on-device test ability.
// The automated host suite executes production logic separately; this file has not itself run on a device.
export function runSensorMathTests(): number {
  assert(clampIntervalNs(50, 100000000, 500000000) === 100000000, 'minimum hardware period');
  assert(clampIntervalNs(1000, 100000000, 500000000) === 500000000, 'maximum hardware period');
  assert(!finiteValues([1, Number.NaN, 3], 3), 'reject NaN');
  assert(!finiteValues([1, 2], 3), 'reject missing value');
  assert(finiteValues([1, 2, 3], 3), 'accept finite values');
  let history: SamplePoint[] = [];
  for (let i: number = 0; i < 500; i++) {
    history = appendHistory(history, 100000 + i * 50, [i]);
  }
  assert(history.length === HISTORY_LIMIT, 'bounded history');
  history = appendHistory(history, 200000, [1]);
  assert(history.length === 1, 'expire old samples');
  return 7;
}
