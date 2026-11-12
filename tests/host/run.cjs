#!/usr/bin/env node
'use strict';
// Executes the actual ArkTS controller after TypeScript transpilation against deterministic platform fakes.
// These assertions are host logic tests, never evidence of HarmonyOS sensor/device behavior.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const studio = process.env.DEVECO_STUDIO_HOME || '/Applications/DevEco-Studio.app/Contents';
const compilerRoot = path.join(studio, 'sdk/default/openharmony/ets/build-tools/ets-loader');
const ts = require(path.join(compilerRoot, 'node_modules/typescript/lib/typescript.js'));
const compatibility = require(path.join(compilerRoot, 'lib/process_available_statement.js'));
require(path.join(compilerRoot, 'main.js')).projectConfig.runtimeOS = 'HarmonyOS';
// Apply the actual SDK26 lowering for apiAvailable so old device fakes need no native API26 method.
function compatibilityTransformer(context) {
  return source => {
    let transformed = false;
    function visit(node) {
      const replacement = compatibility.processAvailableStatement(node);
      if (replacement) { transformed = true; return replacement; }
      return ts.visitEachChild(node, visit, context);
    }
    const updated = ts.visitNode(source, visit);
    return transformed ? ts.factory.updateSourceFile(updated,
      [compatibility.createHelperFunctionDeclaration(), ...updated.statements]) : updated;
  };
}
const root = path.resolve(__dirname, '../..');

function metadata(sensorId, additions = {}) {
  return { sensorId, sensorName: 'Test hardware ' + sensorId, vendorName: 'Fixture',
    firmwareVersion: '0', hardwareVersion: '0', maxRange: 100, minSamplePeriod: 5000000,
    maxSamplePeriod: 1000000000, precision: 0.01, power: 0.1, ...additions };
}

function harness(api = 26, sensors = [metadata(1), metadata(2), metadata(5), metadata(266), metadata(278)]) {
  const state = { now: 100000, timers: new Map(), timerId: 0, sensors, requests: 0, localQueries: [],
    granted: new Set(), subscriptions: new Map(), onCalls: [], offCalls: [],
    onError: undefined, offError: undefined, enumerationError: undefined, request: undefined };
  const names = { ACCELEROMETER: 1, GYROSCOPE: 2, AMBIENT_LIGHT: 5, MAGNETIC_FIELD: 6,
    BAROMETER: 8, HALL: 10, PROXIMITY: 12, HUMIDITY: 13, ORIENTATION: 256, GRAVITY: 257,
    LINEAR_ACCELEROMETER: 258, ROTATION_VECTOR: 259, AMBIENT_TEMPERATURE: 260,
    MAGNETIC_FIELD_UNCALIBRATED: 261, GYROSCOPE_UNCALIBRATED: 263, SIGNIFICANT_MOTION: 264,
    PEDOMETER_DETECTION: 265, PEDOMETER: 266, HEART_RATE: 278, WEAR_DETECTION: 280,
    ACCELEROMETER_UNCALIBRATED: 281, FUSION_PRESSURE: 283 };
  const sensor = {
    SensorId: names,
    getSensorListSync() { if (state.enumerationError) throw state.enumerationError; return state.sensors; },
    getSensorListByDeviceSync(id) { state.localQueries.push(id); return this.getSensorListSync(); },
    on(id, callback, options) {
      state.onCalls.push({ id, callback, options });
      if (state.onError) throw state.onError;
      state.subscriptions.set(id + ':' + (options.sensorInfoParam?.sensorIndex ?? 0), callback);
    },
    off(...args) {
      state.offCalls.push(args);
      if (state.offError) throw state.offError;
      const [id, infoOrCallback, modernCallback] = args;
      const callback = args.length === 3 ? modernCallback : infoOrCallback;
      const index = args.length === 3 ? infoOrCallback?.sensorIndex ?? 0 : 0;
      const key = id + ':' + index;
      if (state.subscriptions.get(key) === callback) state.subscriptions.delete(key);
    }
  };
  const manager = {
    checkAccessTokenSync(token, permission) { return state.granted.has(permission) ? 0 : -1; },
    async requestPermissionsFromUser(context, permissions) {
      state.requests++;
      if (state.request) return await state.request(permissions);
      permissions.forEach(p => state.granted.add(p));
      return { permissions, authResults: [0] };
    }
  };
  const kits = {
    '@kit.SensorServiceKit': { sensor },
    '@kit.BasicServicesKit': { deviceInfo: { sdkApiVersion: api } },
    '@kit.AbilityKit': { abilityAccessCtrl: { createAtManager: () => manager,
      GrantStatus: { PERMISSION_GRANTED: 0 } } }
  };
  const cache = new Map();
  const FakeDate = class extends Date { static now() { return state.now; } };
  const sandbox = vm.createContext({ console, Date: FakeDate,
    setInterval(callback, interval) { const id = ++state.timerId; state.timers.set(id, { callback, interval, repeat: true }); return id; },
    setTimeout(callback, interval) { const id = ++state.timerId; state.timers.set(id, { callback, interval, repeat: false }); return id; },
    clearInterval(id) { state.timers.delete(id); }, clearTimeout(id) { state.timers.delete(id); }
  });
  function load(filename) {
    const full = path.resolve(filename);
    if (cache.has(full)) return cache.get(full).exports;
    const source = fs.readFileSync(full, 'utf8');
    const typedOutput = ts.transpileModule(source, { fileName: full.replace(/\.ets$/, '.ts'),
      compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } });
    // Lower after CommonJS import aliases have been emitted, since the host emitter is not ArkTS's module rewriter.
    const output = ts.transpileModule(typedOutput.outputText, { fileName: full.replace(/\.ets$/, '.js'),
      compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS, allowJs: true },
      transformers: { before: [compatibilityTransformer] } });
    const module = { exports: {} };
    cache.set(full, module);
    const requireLocal = specifier => {
      if (kits[specifier]) return kits[specifier];
      if (specifier.startsWith('.')) return load(path.resolve(path.dirname(full), specifier + '.ets'));
      throw new Error('Unexpected dependency in offline collector: ' + specifier);
    };
    const wrapper = vm.runInContext('(function(exports, require, module){' + output.outputText + '\n})', sandbox,
      { filename: full });
    wrapper(module.exports, requireLocal, module);
    return module.exports;
  }
  const { SensorController } = load(path.join(root, 'entry/src/main/ets/services/SensorController.ets'));
  const controller = new SensorController();
  controller.attach({ applicationInfo: { accessTokenId: 42 } });
  const math = load(path.join(root, 'entry/src/main/ets/model/SensorMath.ets'));
  function emit(id, values, index = 0) {
    const callback = state.subscriptions.get(id + ':' + index);
    assert.ok(callback, 'fixture expected a native subscription for ' + id);
    callback({ timestamp: state.now * 1000000, accuracy: 3, ...values });
  }
  function tick(ms) {
    state.now += ms;
    [...state.timers.entries()].forEach(([id, timer]) => {
      if (!state.timers.has(id)) return;
      if (!timer.repeat) state.timers.delete(id);
      timer.callback();
    });
  }
  function row(id, index = 0) { return controller.snapshot().rows.find(r => r.key === id + ':' + index); }
  return { state, controller, emit, tick, row, math };
}

const cases = [];
function test(name, run) { cases.push({ name, run }); }

test('SDK26 apiAvailable lowering runs on old objects with no native apiAvailable method', async () => {
  const printer = ts.createPrinter();
  const source = ts.createSourceFile('fixture.ts', 'deviceInfo.apiAvailable(19)', ts.ScriptTarget.Latest, true);
  const rewritten = compatibility.processAvailableStatement(source.statements[0].expression);
  assert.equal(printer.printNode(ts.EmitHint.Unspecified, rewritten, source), '__mockApiAvailable(deviceInfo, 19)');
  const helper = printer.printNode(ts.EmitHint.Unspecified, compatibility.createHelperFunctionDeclaration(), source);
  const sandbox = vm.createContext({ deviceInfo: { sdkApiVersion: 12 } });
  assert.equal(vm.runInContext(helper + '; __mockApiAvailable(deviceInfo, 19)', sandbox), false);
  sandbox.deviceInfo.sdkApiVersion = 19;
  assert.equal(vm.runInContext('__mockApiAvailable(deviceInfo, 19)', sandbox), true);
  assert.equal(vm.runInContext('__mockApiAvailable(deviceInfo, 23)', sandbox), false);
});

test('launch enumerates local hardware but neither prompts nor subscribes before foreground', async () => {
  const h = harness(); await h.controller.refresh();
  assert.equal(h.state.requests, 0); assert.equal(h.state.onCalls.length, 0);
  assert.deepEqual(h.state.localQueries, [-1]);
  assert.equal(h.row(278).status, 'qualification');
  assert.equal(h.row(1).status, 'background');
});

test('foreground subscribes only public sensors with granted necessary permissions', async () => {
  const h = harness(); await h.controller.refresh(); h.controller.setForeground(true);
  assert.deepEqual(h.state.onCalls.map(c => c.id), [5]);
  assert.equal(h.row(1).status, 'permission'); assert.equal(h.row(266).status, 'permission');
  assert.equal(h.state.requests, 0); assert.equal(h.row(278).status, 'qualification');
  assert.equal(h.state.onCalls[0].options.sensorInfoParam.deviceId, -1);
  h.state.granted.add('ohos.permission.ACCELEROMETER');
  await h.controller.refresh();
  assert.ok(h.state.subscriptions.has('1:0')); assert.ok(!h.state.subscriptions.has('278:0'));
});

test('motion permission prompt is explicit and denied permission never produces a subscription', async () => {
  const h = harness(); await h.controller.refresh(); h.controller.setForeground(true);
  h.state.request = async () => ({ permissions: ['ohos.permission.ACTIVITY_MOTION'], authResults: [-1] });
  await h.controller.authorizeMotion(); assert.equal(h.state.requests, 1);
  assert.equal(h.row(266).status, 'permission'); assert.ok(!h.state.subscriptions.has('266:0'));
  h.state.request = undefined; await h.controller.authorizeMotion();
  assert.ok(h.state.subscriptions.has('266:0')); assert.equal(h.state.requests, 2);
});

test('late permission result cannot restart collection after background or disposal', async () => {
  const h = harness(); await h.controller.refresh(); h.controller.setForeground(true);
  let finish; h.state.request = () => new Promise(resolve => { finish = resolve; });
  const pending = h.controller.authorizeMotion(); h.controller.setForeground(false);
  h.state.granted.add('ohos.permission.ACTIVITY_MOTION'); finish({ authResults: [0] });
  await pending; assert.equal(h.state.subscriptions.size, 0); assert.equal(h.controller.snapshot().foreground, false);
  h.controller.dispose(); assert.equal(h.state.timers.size, 0);
});

test('pause unsubscribes exact callback and rejects late callback; resume needs new data', async () => {
  const h = harness(); await h.controller.refresh(); h.controller.setForeground(true);
  h.emit(5, { intensity: 12 }); const oldCallback = h.state.subscriptions.get('5:0');
  h.controller.setPaused(true); assert.equal(h.state.subscriptions.size, 0);
  assert.equal(h.row(5).status, 'paused'); oldCallback({ intensity: 999 });
  assert.equal(h.row(5).values[0], 12); assert.equal(h.row(5).history.length, 1);
  assert.equal(h.state.offCalls.at(-1).length, 3); assert.equal(h.state.offCalls.at(-1)[2], oldCallback);
  h.tick(2000); h.controller.setPaused(false); h.tick(1000);
  assert.equal(h.row(5).status, 'waiting'); assert.equal(h.row(5).lastReceivedMs, 100000);
  h.emit(5, { intensity: 13 }); assert.equal(h.row(5).status, 'live');
});

test('resume within the same millisecond still requires a new sample for live status', async () => {
  const h = harness(26, [metadata(5), metadata(10)]); await h.controller.refresh(); h.controller.setForeground(true);
  h.emit(5, { intensity: 1 }); h.emit(10, { status: 1 });
  h.controller.setPaused(true); h.controller.setPaused(false); h.tick(0);
  assert.equal(h.row(5).status, 'waiting'); assert.equal(h.row(10).status, 'waiting');
  h.emit(5, { intensity: 2 }); assert.equal(h.row(5).status, 'live'); assert.equal(h.row(5).values[0], 2);
  h.emit(10, { status: 0 }); assert.equal(h.row(10).status, 'live');
  h.controller.setIntervalMs(100); h.tick(0); assert.equal(h.row(5).status, 'waiting');
});

test('disabled sensors stop and preserve cached history, re-enabled sensor resumes', async () => {
  const h = harness(); await h.controller.refresh(); h.controller.setForeground(true);
  h.emit(5, { intensity: 4 }); h.controller.setEnabled('5:0', false);
  assert.equal(h.row(5).status, 'disabled'); assert.equal(h.state.subscriptions.size, 0);
  assert.equal(h.row(5).values[0], 4); h.controller.setEnabled('5:0', true);
  assert.ok(h.state.subscriptions.has('5:0'));
});

test('revoked system permission is detected before ingesting a callback', async () => {
  const h = harness(26, [metadata(1)]); h.state.granted.add('ohos.permission.ACCELEROMETER');
  await h.controller.refresh(); h.controller.setForeground(true); h.emit(1, { x: 1, y: 2, z: 3 });
  h.state.granted.clear(); h.emit(1, { x: 7, y: 8, z: 9 });
  assert.equal(h.row(1).status, 'permission'); assert.equal(h.row(1).values[0], 1);
  assert.equal(h.state.subscriptions.size, 0);
});

test('missing, NaN and infinite samples are excluded; valid later sample recovers', async () => {
  const h = harness(26, [metadata(1)]); h.state.granted.add('ohos.permission.ACCELEROMETER');
  await h.controller.refresh(); h.controller.setForeground(true);
  h.emit(1, { x: 1, y: 2 }); assert.equal(h.row(1).history.length, 0); assert.equal(h.row(1).status, 'error');
  h.emit(1, { x: NaN, y: 2, z: 3 }); h.emit(1, { x: 1, y: Infinity, z: 3 });
  assert.equal(h.row(1).values.length, 0); h.emit(1, { x: 1, y: 2, z: 3 });
  assert.equal(h.row(1).status, 'live'); assert.equal(h.row(1).history.length, 1);
});

test('optional light fields are returned with units and an explicit unverified-hardware note', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.controller.setForeground(true);
  h.emit(5, { intensity: 42, colorTemperature: 6500, infraredLuminance: 0 });
  assert.equal(h.row(5).values.length, 3); assert.equal(h.row(5).values[1], 6500);
  assert.match(h.row(5).labels[1], /K/); assert.match(h.row(5).message, /占位/);
  h.state.now += 200; h.emit(5, { intensity: 43 });
  assert.equal(h.row(5).values.length, 1); assert.equal(h.row(5).history.length, 1);
});

test('frequency is nanoseconds, clamps to hardware, and unsupported choices are ignored', async () => {
  const h = harness(26, [metadata(5, { minSamplePeriod: 300000000, maxSamplePeriod: 700000000 })]);
  await h.controller.refresh(); h.controller.setForeground(true);
  assert.equal(h.state.onCalls.at(-1).options.interval, 300000000);
  h.controller.setIntervalMs(1000); assert.equal(h.state.onCalls.at(-1).options.interval, 700000000);
  const count = h.state.onCalls.length; h.controller.setIntervalMs(0); h.controller.setIntervalMs(30);
  assert.equal(h.state.onCalls.length, count); assert.equal(h.controller.snapshot().intervalMs, 1000);
});

test('display history decimates real callbacks and bounds both count and age', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.controller.setForeground(true);
  h.controller.setIntervalMs(50); h.emit(5, { intensity: 1 }); h.emit(5, { intensity: 2 });
  assert.equal(h.row(5).history.length, 1); assert.equal(h.row(5).values[0], 1);
  for (let i = 0; i < 500; i++) { h.state.now += 50; h.emit(5, { intensity: i }); }
  assert.equal(h.row(5).history.length, 240);
  h.state.now += 61000; h.emit(5, { intensity: 999 }); assert.equal(h.row(5).history.length, 1);
  assert.equal(h.row(5).history[0].values[0], 999);
});

test('continuous data becomes stale; event sensors remain waiting without fabricated zero', async () => {
  const h = harness(26, [metadata(5), metadata(10)]); await h.controller.refresh(); h.controller.setForeground(true);
  h.tick(6000); assert.equal(h.row(5).status, 'stale'); assert.equal(h.row(10).status, 'waiting');
  assert.equal(h.row(10).values.length, 0); assert.equal(h.row(10).history.length, 0);
  h.emit(10, { status: 1 }); h.tick(60000); assert.equal(h.row(10).status, 'live');
});

test('snapshot is detached and clearHistory only clears graph data', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.controller.setForeground(true); h.emit(5, { intensity: 11 });
  const row = h.row(5); row.values[0] = 999; row.history[0].values[0] = 999; row.labels[0] = 'mutated';
  assert.equal(h.row(5).values[0], 11); assert.equal(h.row(5).history[0].values[0], 11);
  h.controller.clearHistory(); assert.equal(h.row(5).history.length, 0); assert.equal(h.row(5).values[0], 11);
});

test('API19 indexes are addressed independently; mock, remote and duplicate metadata are excluded', async () => {
  const h = harness(26, [metadata(5, { sensorIndex: 0, isLocalSensor: true }),
    metadata(5, { sensorIndex: 1, isLocalSensor: true }), metadata(6, { isLocalSensor: false }),
    metadata(8, { isMockSensor: true }), metadata(5, { sensorIndex: 1 }), metadata(999)]);
  await h.controller.refresh(); h.controller.setForeground(true);
  assert.equal(h.controller.snapshot().excludedCount, 3); assert.equal(h.controller.snapshot().rows.length, 3);
  assert.equal(h.row(999).status, 'unsupported'); h.emit(5, { intensity: 1 }, 0); h.emit(5, { intensity: 2 }, 1);
  assert.equal(h.row(5, 0).values[0], 1); assert.equal(h.row(5, 1).values[0], 2);
  h.controller.setForeground(false); assert.equal(h.state.subscriptions.size, 0);
});

test('API12 uses legacy local enumeration and callback unsubscribe without newer metadata calls', async () => {
  const h = harness(12, [metadata(5), metadata(5), metadata(283)]); await h.controller.refresh(); h.controller.setForeground(true);
  assert.equal(h.state.localQueries.length, 0); assert.equal(h.state.onCalls.length, 1);
  assert.equal(h.state.onCalls[0].options.sensorInfoParam, undefined); assert.equal(h.row(283).status, 'unsupported');
  h.controller.setForeground(false); assert.equal(h.state.offCalls[0].length, 2);
});

test('empty local enumeration is valid; service failure has retryable status and no stale list', async () => {
  const h = harness(26, []); await h.controller.refresh(); assert.equal(h.controller.snapshot().rows.length, 0);
  assert.equal(h.controller.snapshot().enumerationError, ''); h.state.enumerationError = { code: 14500101 };
  await h.controller.refresh(); assert.match(h.controller.snapshot().enumerationError, /14500101/);
  h.state.enumerationError = undefined; h.state.sensors = [metadata(5)]; await h.controller.refresh();
  assert.equal(h.controller.snapshot().enumerationError, ''); assert.equal(h.controller.snapshot().rows.length, 1);
});

test('native subscription failures map permission and unsupported error codes', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.state.onError = { code: 14500102 };
  h.controller.setForeground(true); assert.equal(h.row(5).status, 'unsupported');
  h.state.onError = { code: 201 }; await h.controller.refresh(); assert.equal(h.row(5).status, 'permission');
  h.state.onError = undefined; await h.controller.refresh(); assert.equal(h.row(5).status, 'waiting');
});

test('failed native cleanup rejects late data and does not overwrite its stop callback', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.controller.setForeground(true);
  const original = h.state.subscriptions.get('5:0'); h.emit(5, { intensity: 5 }); h.state.offError = { code: 14500101 };
  h.controller.setPaused(true); assert.equal(h.row(5).status, 'error');
  original({ intensity: 999 }); assert.equal(h.row(5).values[0], 5);
  h.controller.setPaused(false); assert.equal(h.state.onCalls.length, 1); assert.equal(h.row(5).status, 'error');
  h.state.offError = undefined; await h.controller.refresh(); assert.ok(h.state.onCalls.length > 1);
  h.controller.dispose(); assert.equal(h.state.subscriptions.size, 0);
});

test('refresh cannot create another subscription while the previous instance still needs cleanup', async () => {
  const h = harness(26, [metadata(5)]); await h.controller.refresh(); h.controller.setForeground(true);
  const original = h.state.subscriptions.get('5:0'); h.emit(5, { intensity: 5 });
  h.state.offError = { code: 14500101 };
  await h.controller.refresh();
  assert.equal(h.state.onCalls.length, 1, 'refresh must not duplicate a failed native subscription');
  assert.equal(h.row(5).status, 'error');
  original({ intensity: 999 }); assert.equal(h.row(5).values.length, 0);
  h.controller.setIntervalMs(100); assert.equal(h.state.onCalls.length, 1);
  h.state.offError = undefined; await h.controller.refresh();
  assert.equal(h.state.onCalls.length, 2); h.emit(5, { intensity: 7 });
  assert.equal(h.row(5).values[0], 7); h.controller.dispose();
  assert.equal(h.state.subscriptions.size, 0);
});

(async () => {
  let failures = 0;
  for (const c of cases) {
    try { await c.run(); console.log('PASS ' + c.name); }
    catch (error) { failures++; console.error('FAIL ' + c.name + '\n' + error.stack); }
  }
  console.log('\nHost logic tests: ' + (cases.length - failures) + '/' + cases.length + ' passed. No device verification claimed.');
  process.exitCode = failures ? 1 : 0;
})();
