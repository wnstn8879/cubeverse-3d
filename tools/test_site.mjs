// Exercise generated host adapter with exact exported bytes, without a browser.
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
const directory = path.resolve(process.argv[2] || '/workspace/sites/cubeverse-play/dist');
const manifest = JSON.parse(await fs.readFile(path.join(directory, 'artifacts.json'), 'utf8'));
globalThis.window = globalThis;
globalThis.location = new URL('https://example.test/cubeverse/');
globalThis.document = { baseURI: new URL('index.html', location).href };
let requests = 0;
globalThis.fetch = async input => {
  requests++;
  const filename = path.basename(new URL(String(input), document.baseURI).pathname);
  return new Response(await fs.readFile(path.join(directory, filename)));
};
vm.runInThisContext(await fs.readFile(path.join(directory, 'host-loader.js'), 'utf8'));
const response = await window.fetch('index.wasm');
if (response.headers.get('Content-Type') !== 'application/wasm') throw Error('Wrong WASM MIME');
const data = Buffer.from(await response.clone().arrayBuffer());
if (data.length !== manifest.engine.bytes) throw Error('Wrong WASM length');
if (crypto.createHash('sha256').update(data).digest('hex') !== manifest.engine.sha256) throw Error('Wrong WASM bytes');
await WebAssembly.compileStreaming(response);
await window.fetch('index.wasm');
if (requests !== manifest.engine.parts.length) throw Error('WASM cache loaded twice');
const passthrough = await window.fetch('artifacts.json');
if (!(await passthrough.json()).engine) throw Error('Other fetch was intercepted');
if (manifest.apk) {
  const bytes = Buffer.concat(await Promise.all(manifest.apk.parts.map(p => fs.readFile(path.join(directory, p)))));
  if (crypto.createHash('sha256').update(bytes).digest('hex') !== manifest.apk.sha256) throw Error('APK reconstruction differs');
}
console.log('STATIC_HOST_ADAPTER_PASS: exact WASM and APK bytes, compileStreaming, cache and passthrough');
