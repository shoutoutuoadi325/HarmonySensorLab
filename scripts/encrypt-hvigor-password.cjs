'use strict';
// Adapt a local keystore password to the installed IDE format without writing plaintext.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const request = JSON.parse(fs.readFileSync(0, 'utf8'));
if (!request.password || !request.materialDirectory || !request.outputFile || !request.studioDirectory) {
  throw new Error('Incomplete local signing password request');
}
const decoderPath = path.join(request.studioDirectory, 'tools/hvigor/hvigor-ohos-plugin/src/utils/decipher-util.js');
const { DecipherUtil } = require(decoderPath);
const key = Buffer.from(DecipherUtil.getKey(request.materialDirectory, 'local Release signing'));
if (key.length !== 16) throw new Error('Unexpected IDE password material');
function encryptedPassword() {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-128-gcm', key, iv);
  const content = Buffer.concat([cipher.update(Buffer.from(request.password, 'utf8')), cipher.final(), cipher.getAuthTag()]);
  const header = Buffer.alloc(4);
  header.writeUInt32BE(content.length);
  const encrypted = Buffer.concat([header, iv, content]).toString('hex');
  const decoded = DecipherUtil.decryptPwd(request.materialDirectory, encrypted, 'local Release signing');
  const expected = Buffer.from(request.password, 'utf8');
  const actual = Buffer.from(decoded, 'utf8');
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) {
    throw new Error('IDE password round trip failed');
  }
  return encrypted;
}
fs.writeFileSync(request.outputFile, JSON.stringify({ storePassword: encryptedPassword(), keyPassword: encryptedPassword() }),
  { flag: 'wx', mode: 0o600 });
key.fill(0);
