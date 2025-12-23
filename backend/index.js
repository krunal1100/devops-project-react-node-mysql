// backend/index.js
const express = require('express');
const client = require('prom-client');
const app = express();
const db = require('./db');

app.use(express.json());

// ---- PROMETHEUS METRICS SETUP ----
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ prefix: 'backend_' });

const httpRequestCounter = new client.Counter({
  name: 'backend_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});

app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestCounter.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode
    });
  });
  next();
});

// ---- HEALTH ----
app.get('/health', (req, res) => res.send('ok'));

// ---- METRICS ENDPOINT ----
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// ---- API ----
app.get('/api/users', (req, res) => {
  db.query('SELECT * FROM users', (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post('/api/users', (req, res) => {
  const { name, email } = req.body;
  db.query(
    'INSERT INTO users (name,email) VALUES (?,?)',
    [name, email],
    err => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'User created' });
    }
  );
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log('Backend running on port', port));
