// routes/auth.js
const express = require('express');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const pool    = require('../db');
const { authLimiter }    = require('../middleware/rateLimiter');
const verifyCaptcha      = require('../middleware/verifyCaptcha');

const router = express.Router();

// ─── REGISTER ────────────────────────────────────────────────────────────────
router.post(
  '/register',
  authLimiter,
  verifyCaptcha,
  async (req, res) => {
    const { name, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    try {
      // check existing
      const { rows } = await pool.query(
        'SELECT id FROM users WHERE email=$1',
        [email]
      );
      if (rows.length) {
        return res.status(400).json({ error: 'Email already in use' });
      }

      // hash & insert
      const hashed = await bcrypt.hash(password, 10);
      const result = await pool.query(
        `INSERT INTO users (name,email,password)
         VALUES ($1,$2,$3)
         RETURNING id,name,email,created_at`,
        [name, email, hashed]
      );

      res.status(201).json({ user: result.rows[0] });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

// ─── LOGIN ───────────────────────────────────────────────────────────────────
router.post(
  '/login',
  authLimiter,
  verifyCaptcha,
  async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    try {
      const { rows } = await pool.query(
        `SELECT id,name,email,password
         FROM users
         WHERE email=$1`,
        [email]
      );
      if (!rows.length) {
        return res.status(400).json({ error: 'Invalid credentials' });
      }

      const user = rows[0];
      const match = await bcrypt.compare(password, user.password);
      if (!match) {
        return res.status(400).json({ error: 'Invalid credentials' });
      }

      // issue tokens
      const payload = { userId: user.id, email: user.email };
      const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
        expiresIn: '1h'
      });
      const refreshToken = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, {
        expiresIn: '7d'
      });

      res.json({ accessToken, refreshToken });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

// ─── REFRESH TOKEN ────────────────────────────────────────────────────────────
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token required' });
  }
  try {
    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const newAccess = jwt.sign(
      { userId: payload.userId, email: payload.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    res.json({ accessToken: newAccess });
  } catch (err) {
    console.error(err);
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

module.exports = router;