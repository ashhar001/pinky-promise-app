// middleware/rateLimiter.js
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,   // 5 minutes
  max: 30,                   // limit each IP to 30 requests per window
  message: { error: 'Too many authentication attempts. Please wait 5 minutes before trying again.' }
});

module.exports = { authLimiter };