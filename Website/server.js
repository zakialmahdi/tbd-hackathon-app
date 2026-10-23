const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = parseInt(process.env.PORT, 10) || 3000;
const HOST = '127.0.0.1';
const DIR = __dirname;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8'
};

const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';

  // Decode URI component safely
  let safePath;
  try {
    safePath = path.normalize(decodeURIComponent(reqPath)).replace(/^(\.\.[\/\\])+/, '');
  } catch {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end('Bad Request');
    return;
  }

  const filePath = path.join(DIR, safePath);

  // Security check: ensure path is within DIR
  if (!filePath.startsWith(DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<!doctype html><html><head><title>404 Not Found</title><link rel="stylesheet" href="styles.css"></head><body><div class="card" style="margin:40px auto;max-width:400px;text-align:center;"><h2>Page Not Found</h2><p class="sub">The requested file <code>${reqPath}</code> was not found.</p><p><a href="index.html" class="btn">Return to Home</a></p></div></body></html>`);
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache'
    });

    fs.createReadStream(filePath).pipe(res);
  });
});

function startServer(port) {
  server.listen(port, HOST, () => {
    const url = `http://localhost:${port}/`;
    console.log('\n==================================================');
    console.log(`  🌿 VertivEra Admin Console is running!`);
    console.log(`  URL: ${url}`);
    console.log('==================================================\n');
    console.log('  Press Ctrl+C to stop the server.\n');

    // Auto-open browser
    const startCmd = process.platform === 'win32'
      ? `start "" "${url}"`
      : process.platform === 'darwin'
        ? `open "${url}"`
        : `xdg-open "${url}"`;

    if (process.env.NO_OPEN !== '1') {
      exec(startCmd, () => {});
    }
  });

  server.on('error', err => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`Port ${port} in use, trying port ${port + 1}...`);
      startServer(port + 1);
    } else {
      console.error('Server error:', err);
    }
  });
}

startServer(PORT);

