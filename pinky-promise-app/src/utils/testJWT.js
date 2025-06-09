// src/utils/testJWT.js
// Save this file and run it with Node.js to test your JWT endpoints

const fetch = require('node-fetch');

async function testJWT() {
  console.log('Testing JWT endpoints...');
  const baseUrl = 'http://localhost:8000'; // Update with your backend URL
  
  try {
    // Test login
    console.log('Testing login...');
    const loginResponse = await fetch(`${baseUrl}/api/token/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        username: 'your_test_username',  // Replace with a real username
        password: 'your_test_password'   // Replace with a real password
      }),
    });
    
    const loginData = await loginResponse.json();
    
    if (!loginResponse.ok) {
      throw new Error(`Login failed: ${loginResponse.status} - ${JSON.stringify(loginData)}`);
    }
    
    console.log('Login successful!');
    console.log('Access token:', loginData.access);
    console.log('Refresh token:', loginData.refresh);
    
    // Test token verification
    console.log('\nTesting token verification...');
    const verifyResponse = await fetch(`${baseUrl}/api/token/verify/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: loginData.access,
      }),
    });
    
    if (!verifyResponse.ok) {
      const verifyData = await verifyResponse.json();
      throw new Error(`Verification failed: ${verifyResponse.status} - ${JSON.stringify(verifyData)}`);
    }
    
    console.log('Token verification successful!');
    
    // Test refresh token
    console.log('\nTesting refresh token...');
    const refreshResponse = await fetch(`${baseUrl}/api/token/refresh/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        refresh: loginData.refresh,
      }),
    });
    
    const refreshData = await refreshResponse.json();
    
    if (!refreshResponse.ok) {
      throw new Error(`Refresh failed: ${refreshResponse.status} - ${JSON.stringify(refreshData)}`);
    }
    
    console.log('Token refresh successful!');
    console.log('New access token:', refreshData.access);
    
  } catch (error) {
    console.error('Error during JWT testing:', error.message);
  }
}

testJWT();
