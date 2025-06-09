// server.js
require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const authRouter = require('./routes/auth');

const app = express();
app.use(cors());
app.use(express.json());

// ← Add this health-check / root route:
app.get('/', (req, res) => {
  res.send('🩷 Pinky Promise Auth API is up!');
});

// mount your auth endpoints under /api/auth
app.use('/api/auth', authRouter);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server listening on http://localhost:${PORT}`);
});