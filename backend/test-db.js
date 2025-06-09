const { testConnection } = require('./db');

// Run the test
console.log('Testing database connection...');
testConnection()
  .then(() => {
    console.log('Test completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Test failed:', error);
    process.exit(1);
  }); 