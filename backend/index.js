// backend/index.js
const express = require('express');
const app = express();
const db = require('./db');
app.use(express.json());

// health
app.get('/health', (req, res) => res.send('ok'));

// users example
app.get('/api/users', (req, res) => {
  db.query('SELECT * FROM users', (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post('/api/users', (req, res) => {
  const { name, email } = req.body;
  db.query('INSERT INTO users (name,email) VALUES (?,?)', [name, email], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'User created' });
  });
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log('Backend running on port', port));
