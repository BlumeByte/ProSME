const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'build', 'web');
const port = Number(process.env.PORT || 5008);
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
  '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream', '.ico': 'image/x-icon', '.txt': 'text/plain',
};

// Build a trusted file catalogue at startup. Request strings are only Map keys;
// they never become filesystem paths. Restart after rebuilding the web app.
function catalogue(directory, prefix = '', files = new Map()) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) continue;
    const file = path.join(directory, entry.name);
    const key = `${prefix}/${entry.name}`;
    if (entry.isDirectory()) catalogue(file, key, files);
    else if (entry.isFile()) files.set(key, file);
  }
  return files;
}

function createServer(directory = root) {
  const files = catalogue(directory);
  return http.createServer((req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { Allow: 'GET, HEAD' }).end();
      return;
    }
    let urlPath;
    try {
      urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
    } catch {
      res.writeHead(400).end('Invalid URL');
      return;
    }
    if (urlPath.includes('\0') || urlPath.includes('\\') ||
        urlPath.split('/').some((part) => part === '..' || part === '.')) {
      res.writeHead(400).end('Invalid path');
      return;
    }
    const file = files.get(urlPath) || files.get('/index.html');
    if (!file) {
      res.writeHead(404).end('Not found');
      return;
    }
    const stream = fs.createReadStream(file);
    stream.once('error', () => {
      if (!res.headersSent) res.writeHead(404).end('Not found');
      else res.destroy();
    });
    stream.once('open', () => {
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
      if (req.method === 'HEAD') {
        stream.destroy();
        res.end();
      } else stream.pipe(res);
    });
    res.once('close', () => stream.destroy());
  });
}

if (require.main === module) {
  createServer().listen(port, '127.0.0.1', () => console.log(`serving ${root} on ${port}`));
}
module.exports = { createServer };
