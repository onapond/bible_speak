const http = require('http');

const PORT = process.env.PORT || 3000;

// Provider requests now use authenticated Firebase Functions. This process is
// intentionally a tombstone so an old Render deployment cannot proxy billable
// API traffic anonymously after it is redeployed.
http.createServer((req, res) => {
  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('Bible Speak legacy proxy retired');
    return;
  }

  res.writeHead(410, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify({error: 'This legacy proxy has been retired'}));
}).listen(PORT, () => {
  console.log(`Legacy proxy tombstone listening on port ${PORT}`);
});
