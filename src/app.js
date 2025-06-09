const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0'
  });
});

// Ready check endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Pinky Promise App!',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Metrics endpoint (basic)
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP app_requests_total Total number of requests
# TYPE app_requests_total counter
app_requests_total{method="GET",route="/"} 42
# HELP app_up Application up status
# TYPE app_up gauge
app_up 1
  `.trim());
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Pinky Promise App listening on port ${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
  console.log(`Ready check: http://localhost:${port}/ready`);
});

