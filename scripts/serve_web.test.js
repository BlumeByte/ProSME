const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { createServer } = require('./serve_web');

test('preview serves only catalogued files and survives hostile URLs', async (t) => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'prosme-preview-'));
  const root = path.join(temporary, 'web');
  fs.mkdirSync(root);
  fs.writeFileSync(path.join(root, 'index.html'), 'app shell');
  fs.writeFileSync(path.join(root, 'main.js'), 'app asset');
  fs.writeFileSync(path.join(temporary, 'private.txt'), 'PRIVATE');
  const server = createServer(root);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(temporary, { recursive: true, force: true });
  });
  const request = (url, method = 'GET') => new Promise((resolve, reject) => {
    http.request({ hostname: '127.0.0.1', port: server.address().port, path: url, method }, (res) => {
      let body = '';
      res.on('data', (data) => body += data);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject).end();
  });
  assert.deepEqual(await request('/main.js?v=1'), { status: 200, body: 'app asset' });
  assert.deepEqual(await request('/profile'), { status: 200, body: 'app shell' });
  for (const url of ['/../private.txt', '/%2e%2e/private.txt', '/..%5cprivate.txt', '/%00', '/%ZZ']) {
    assert.equal((await request(url)).status, 400, url);
  }
  assert.equal((await request('/', 'POST')).status, 405);
  assert.deepEqual(await request('/main.js', 'HEAD'), { status: 200, body: '' });
  fs.unlinkSync(path.join(root, 'main.js'));
  assert.equal((await request('/main.js')).status, 404);
  assert.equal((await request('/')).status, 200);
});
