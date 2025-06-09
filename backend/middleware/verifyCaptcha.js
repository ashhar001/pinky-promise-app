// middleware/verifyCaptcha.js

async function verifyCaptcha(req, res, next) {
  const fetch = (await import('node-fetch')).default;
  const token = req.body.captchaToken;
  if (!token) return res.status(400).json({ error: 'Missing captcha token' });

  try {
    const secret = process.env.RECAPTCHA_SECRET_KEY;
    const resp = await fetch(
      `https://www.google.com/recaptcha/api/siteverify?secret=${secret}&response=${token}`,
      { method: 'POST' }
    );
    const data = await resp.json();
    if (!data.success) {
      return res.status(400).json({ error: 'Captcha verification failed' });
    }
    next();
  } catch (err) {
    console.error('Captcha error:', err);
    res.status(500).json({ error: 'Captcha service error' });
  }
}

module.exports = verifyCaptcha;