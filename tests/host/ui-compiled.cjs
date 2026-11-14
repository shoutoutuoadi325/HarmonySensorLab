'use strict';
// Tests real SDK-generated UI functions and lifecycle handlers. No device behavior is claimed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const studio = process.env.DEVECO_STUDIO_HOME || '/Applications/DevEco-Studio.app/Contents';
const ts = require(path.join(studio, 'tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js'));
const root = path.resolve(__dirname, '../..');
const buildMode = process.env.HARMONY_UI_BUILD_MODE || 'debug';
assert.ok(['debug', 'release'].includes(buildMode), 'UI test build mode must be debug or release');
const compiled = path.join(root, 'entry/build/default/cache/default/default@CompileArkTS/esmodule', buildMode, 'entry/src/main/ets');
const tr = zh => zh;
function source(name) { return ts.createSourceFile(name, fs.readFileSync(path.join(compiled, name), 'utf8'), ts.ScriptTarget.Latest, true); }
function find(node, predicate) {
  if (predicate(node)) return node;
  let result;
  ts.forEachChild(node, child => { if (!result) result = find(child, predicate); });
  return result;
}
function runnable(text, globals = {}) {
  const code = ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
  return vm.runInNewContext(code, globals);
}
function pageMethod(name) {
  const method = find(index, n => ts.isMethodDeclaration(n) && n.name.getText(index) === name);
  assert.ok(method, 'rebuild the entry page before testing ' + name);
  return runnable('(function ' + method.getText(index).replace(/^private\s+/, '') + ')', { tr });
}
let count = 0;
function test(label, callback) { callback(); count++; console.log('PASS ' + label); }
const index = source('pages/Index.ts');
const binding = find(index, n => ts.isArrowFunction(n) && n.parameters.length === 2 &&
  ts.isBlock(n.body) && ts.isIfStatement(n.body.statements[0]) &&
  n.body.statements[0].expression.getText(index) === n.parameters[1].name.getText(index) &&
  n.getText(index).includes('new SensorCardView(') && n.getText(index).includes('this.currentRow('));
assert.ok(binding, 'compile with scripts/build.sh before testing generated UI');
const rowArgument = find(binding, n => ts.isCallExpression(n) && ts.isPropertyAccessExpression(n.expression) &&
  n.expression.name.getText(index) === 'currentRow').arguments[0];
assert.ok(ts.isIdentifier(rowArgument), 'card update must capture the hardware row');
const currentRowMethod = find(index, n => ts.isMethodDeclaration(n) && n.name.getText(index) === 'currentRow');
const currentRow = runnable('(function ' + currentRowMethod.getText(index).replace(/^private\s+/, '') + ')');
test('stable hardware key update reads newest snapshot and retains card component', () => {
  const oldRow = { key: '1:0', values: [1], status: 'live' };
  const newRow = { key: '1:0', values: [9], status: 'paused' };
  let creates = 0; let child; let updated;
  const update = runnable('(function(' + binding.parameters.map(p => p.getText(index)).join(',') + ') ' + binding.body.getText(index) + ')', { [rowArgument.getText(index)]: oldRow,
    SensorCardView: class { constructor(parent, props) { creates++; child = this; this.props = props; } },
    ViewPU: { create() {} } });
  const view = { snapshot: { rows: [oldRow] }, currentRow, wearable: false, television: false,
    cardWidth: () => 320, showDetails: false, updateStateVarsOfChildByElmtId(id, props) { updated = props; } };
  update.call(view, 42, true); view.snapshot = { rows: [newRow] }; view.showDetails = true;
  update.call(view, 42, false);
  assert.equal(creates, 1); assert.equal(updated.row, newRow); assert.equal(updated.showDetails, true);
  assert.equal(child.paramsGenerator_().row, newRow);
});
const chart = source('components/SensorChart.ts');
const drawMethod = find(chart, n => ts.isMethodDeclaration(n) && n.name.getText(chart) === 'draw');
const draw = runnable('(function ' + drawMethod.getText(chart) + ')', { tr });
function plot(history, additions = {}) {
  const commands = [];
  const context = new Proxy({}, { get(target, name) { return (...args) => { commands.push([name, ...args]); }; },
    set(target, name, value) { commands.push(['set', name, value]); return true; } });
  draw.call({ ready: true, canvasWidth: 300, canvasHeight: 124, context,
    axis: 0, colors: ['green', 'red'], row: { history, labels: ['X', 'Y'], eventDriven: false,
      requestedIntervalNs: 200000000 }, ...additions });
  for (const command of commands) for (const arg of command) {
    if (typeof arg === 'number') assert.ok(Number.isFinite(arg), 'canvas coordinate must be finite');
  }
  return commands;
}
test('empty chart clears old pixels and reports waiting', () => {
  const commands = plot([]);
  assert.equal(commands[0][0], 'clearRect');
  assert.ok(commands.some(c => c[0] === 'fillText' && c[1] === '等待真实样本'));
});
test('flat selected component keeps finite bounds and excludes other units', () => {
  const commands = plot([{ timeMs: 1000, values: [3, 5000] }, { timeMs: 1200, values: [3, 7000] }]);
  const ticks = commands.filter(c => c[0] === 'fillText');
  assert.ok(ticks.some(c => c[1] === '3.5')); assert.ok(!ticks.some(c => c[1] === '7560.0'));
});
test('continuous chart leaves long sampling gaps unconnected', () => {
  const commands = plot([{ timeMs: 1000, values: [1, 0] }, { timeMs: 10000, values: [2, 0] }]);
  // Four horizontal grid lines only; no data segment across the missing interval.
  assert.equal(commands.filter(c => c[0] === 'lineTo').length, 4);
});
test('event chart uses points without suggesting continuous measurements', () => {
  const commands = plot([{ timeMs: 1000, values: [1] }, { timeMs: 1200, values: [2] }],
    { row: { history: [{ timeMs: 1000, values: [1] }, { timeMs: 1200, values: [2] }],
      labels: ['event'], eventDriven: true, requestedIntervalNs: 200000000 } });
  assert.equal(commands.filter(c => c[0] === 'lineTo').length, 4);
  assert.equal(commands.filter(c => c[0] === 'arc').length, 2);
});
test('optional field disappearance clamps previously selected component', () => {
  plot([{ timeMs: 1000, values: [1] }], { axis: 5, row: { history: [{ timeMs: 1000, values: [1] }],
    labels: ['lux'], eventDriven: false, requestedIntervalNs: 200000000 } });
});
function selectUpdate(tree) {
  const node = find(tree, n => ts.isArrowFunction(n) && n.parameters.length === 2 &&
    ts.isBlock(n.body) && n.body.statements[0]?.getText(tree).startsWith('Select.create('));
  assert.ok(node);
  const commands = [];
  const Select = new Proxy({}, { get(_target, name) { return (...args) => commands.push([name, ...args]); } });
  return { update: runnable('(function(' + node.parameters.map(p => p.getText(tree)).join(',') + ') ' + node.body.getText(tree) + ')', { Select, tr }), commands };
}
test('frequency menu update avoids live sensor snapshot dependency', () => {
  const { update, commands } = selectUpdate(index);
  update.call({ get snapshot() { throw Error('Live snapshot would dismiss menu'); },
    selectedIntervalMs: 50, textSize: () => 14, buttonSize: () => 44 }, 1, false);
  assert.ok(commands.some(c => c[0] === 'selected' && c[1] === 3));
});
test('component menu update avoids live row dependency', () => {
  const card = source('components/SensorCardView.ts');
  const { update, commands } = selectUpdate(card);
  const safe = find(card, n => ts.isMethodDeclaration(n) && n.name.getText(card) === 'safeAxis');
  const safeAxis = runnable('(function ' + safe.getText(card).replace(/^private\s+/, '') + ')');
  update.call({ get row() { throw Error('Live row would dismiss menu'); }, axisLabels: ['X', 'Y'],
    selectedAxis: 1, safeAxis, curveDescription: '加速度曲线分量', textSize: () => 14 }, 1, false);
  assert.ok(commands.some(c => c[0] === 'value' && c[1] === 'Y'));
});
test('TV activation consumes supported key down once and preserves other keys', () => {
  const method = find(index, n => ts.isMethodDeclaration(n) && n.name.getText(index) === 'activateKey');
  const activate = runnable('(function ' + method.getText(index).replace(/^private\s+/, '') + ')', { KeyType: { Down: 0, Up: 1 } });
  let calls = 0;
  for (const keyCode of [2016, 2054, 2050]) assert.equal(activate.call({ television: true }, { type: 0, keyCode }, () => calls++), true);
  assert.equal(calls, 3);
  assert.equal(activate.call({ television: true }, { type: 1, keyCode: 2054 }, () => calls++), false);
  assert.equal(activate.call({ television: true }, { type: 0, keyCode: 2013 }, () => calls++), false);
  assert.equal(activate.call({ television: false }, { type: 0, keyCode: 2054 }, () => calls++), false);
  assert.equal(calls, 3);
});
test('hidden cached page pauses until explicitly restarted', () => {
  const controller = { paused: false, foreground: true, onChange: undefined,
    snapshot() { return { paused: this.paused, intervalMs: 200 }; },
    setPaused(value) { this.paused = value; this.onChange?.(); },
    refresh() { this.refreshed = true; },
    setForeground() { throw Error('page lifecycle must not assert ability foreground'); } };
  const view = { controller, selectedIntervalMs: 200, started: true, privacyDecision: 'accepted',
    loadPrivacyDecision() {}, updateSnapshot: pageMethod('updateSnapshot'), focusForTv() {} };
  pageMethod('aboutToAppear').call(view);
  assert.equal(controller.paused, false);
  pageMethod('onPageHide').call(view);
  assert.equal(controller.paused, true); assert.equal(view.snapshot.paused, true);
  assert.equal(controller.refreshed, undefined);
  pageMethod('startObservation').call(view);
  assert.equal(controller.paused, false); assert.equal(controller.refreshed, true);
});
test('destroyed page removes its listener before pausing the collector', () => {
  const controller = { paused: false, onChange: undefined, snapshot() { return { paused: this.paused, intervalMs: 200 }; },
    setPaused(value) { this.paused = value; this.onChange?.(); },
    setForeground() { throw Error('page lifecycle must not assert ability foreground'); } };
  let closing = false; let snapshot;
  const view = { controller, selectedIntervalMs: 200, loadPrivacyDecision() {}, updateSnapshot: pageMethod('updateSnapshot') };
  Object.defineProperty(view, 'snapshot', { get: () => snapshot, set(value) {
    assert.equal(closing, false, 'destroyed page must not receive state updates'); snapshot = value; } });
  pageMethod('aboutToAppear').call(view); closing = true;
  pageMethod('aboutToDisappear').call(view);
  assert.equal(controller.paused, true); assert.equal(controller.onChange, undefined); assert.equal(view.mounted, false);
});
test('first release footer excludes TV while preserving the deferred TV branch', () => {
  const summary = pageMethod('deviceSummary');
  const firstRelease = summary.call({ television: false });
  assert.ok(!firstRelease.includes('智慧屏'));
  for (const device of ['手机', '平板', 'PC', '智能手表']) assert.ok(firstRelease.includes(device));
  assert.ok(summary.call({ television: true }).includes('智慧屏'));
});
console.log('UI host tests: ' + count + '/' + count + ' passed. No layout/device verification claimed.');
