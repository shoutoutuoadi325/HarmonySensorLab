'use strict';
// Checks SDK-generated Release policy-link behavior with local ability fakes, not a system browser.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const studio = process.env.DEVECO_STUDIO_HOME || '/Applications/DevEco-Studio.app/Contents';
const ts = require(path.join(studio, 'tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js'));
const root = path.resolve(__dirname, '../..');
const generated = path.join(root, 'entry/build/default/cache/default/default@CompileArkTS/esmodule/release/entry/src/main/ets/model/PrivacyPolicyLink.ts');
const source = fs.readFileSync(generated, 'utf8');
const output = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } });
const moduleObject = { exports: {} };
vm.runInNewContext(output.outputText, { module: moduleObject, exports: moduleObject.exports,
  require(name) { throw new Error('Unexpected platform dependency in policy-link host test: ' + name); } });
const link = moduleObject.exports;
let passed = 0;
async function test(name, action) { await action(); passed++; console.log('PASS ' + name); }
(async () => {
  await test('Release has the verified public HTTPS policy address', async () => {
    assert.equal(link.hasPrivacyPolicyUrl(), true);
    assert.equal(link.PRIVACY_POLICY_URL, 'https://harmonysensorlab-privacy.netlify.app/');
  });
  await test('missing ability context fails without opening another application', async () => {
    assert.equal(await link.openPrivacyPolicy(undefined), false);
  });
  await test('policy browser request contains only the public URI and standard view fields', async () => {
    let received;
    assert.equal(await link.openPrivacyPolicy({ async startAbility(want) { received = want; } }), true);
    assert.equal(received.uri, link.PRIVACY_POLICY_URL);
    assert.equal(received.action, 'ohos.want.action.viewData');
    assert.equal(Array.from(received.entities).join(','), 'entity.system.browsable');
    assert.equal(Object.keys(received).sort().join(','), 'action,entities,uri');
  });
  await test('no eligible system browser returns failure for the local-policy fallback', async () => {
    assert.equal(await link.openPrivacyPolicy({ async startAbility() { throw new Error('no eligible browser'); } }), false);
  });
  console.log('Release privacy host tests: ' + passed + '/4 passed. No browser/device verification claimed.');
})().catch(error => { console.error(error.stack); process.exitCode = 1; });
